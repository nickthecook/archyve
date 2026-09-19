module Sources
  # The sync engine. Diffs what a source currently reports against the
  # Documents it has already produced, and reconciles the difference.
  #
  # Deliberately knows nothing about folders, S3, or Bookstack. A source only
  # has to answer two questions — "what is there?" (#each_item, yielding items
  # with a stable external_id and a version token) and "give me this one's
  # bytes" (#read) — and it can be synced by this class unchanged.
  #
  # The scan runs to completion synchronously, so the counts it records are
  # final when it returns. What it does *not* do is fetch or process anything:
  # each changed item is handed to Sources::ImportItemJob, so one unreadable
  # file or one slow download can't stall the scan or lose the rest of the diff.
  class Sync
    def self.call(...) = new(...).call

    def initialize(source)
      @source = source
      @counts = Hash.new(0)
      @seen = Set.new
    end

    def call
      run = source.syncs.create!(started_at: Time.current)

      begin
        scan(run)
        tombstone_vanished(run)
        finish(run, status: :completed)
      rescue StandardError => e
        finish(run, status: :failed, error: "#{e.class}: #{e.message}")
        raise
      end

      run
    end

    private

    attr_reader :source, :counts, :seen

    def scan(run)
      source.each_item do |item|
        seen << item.external_id
        counts[:found] += 1
        reconcile(item, run)
      rescue StandardError => e
        # One bad item shouldn't cost us the other thousand: count it, log it,
        # keep scanning.
        #
        # Note what can actually land here — reconcile only reads our own tables,
        # writes the document row, and enqueues. Nothing touches the source's
        # bytes, which ImportItemJob does later on a worker. So these are
        # bookkeeping errors, not read errors, and the UI calls them "errored"
        # rather than anything implying we tried to read the file.
        #
        # The item stays out of `seen`, so it isn't tombstoned: an item we failed
        # to record is not an item we know to be gone.
        counts[:failed] += 1
        Rails.logger.error("Source #{source.id} failed on #{item.external_id}: #{e.class}: #{e.message}")
      end
    end

    def reconcile(item, run)
      document = source.documents.find_by(external_id: item.external_id)

      # Present in the source but not ingestable — too large, or whatever a
      # future source decides it can't take. It counts as seen, so it is not
      # tombstoned, and any document already built from it is left exactly as it
      # is. Tightening a limit must never delete documents.
      return count_uningestable(document, item) if item.skipped?

      if document.nil?
        counts[:created] += 1
        import(create_document(item, run), item)
      elsif changed?(document, item)
        counts[:updated] += 1
        document.update!(**description(document, item), source_sync: run)
        import(document, item)
      else
        counts[:unchanged] += 1
        redescribe(document, item)
      end
    end

    # How the source describes the item, as against its content: title, where it
    # sits, how to reach it. Everything but the version token and the bytes.
    def description(document, item)
      {
        title: item.title,
        content_type: item.content_type,
        path: item.path,
        url: item.url,
        source_metadata: document.source_metadata.merge(item.metadata)
      }
    end

    # Rewrite the description of an item whose version hasn't moved. Renaming a
    # Bookstack book changes the path of every page in it without touching a
    # single revision, and folding the path into the version token instead would
    # mean refetching all of them to discover the bytes were identical.
    def redescribe(document, item)
      changes = description(document, item).reject { |attribute, value| document.public_send(attribute) == value }

      document.update!(changes) if changes.any?
    end

    # An item we can't ingest lands in one of three quite different places, and
    # they are worth separating because only one of them is a problem:
    #
    #   skipped   nothing in the archive — the source has it, we never took it
    #   unchanged we have it and it still matches; we simply couldn't re-take it
    #             if it changed. The document is accurate, so this is not news.
    #   stale     we have it, the source has moved on, and the document cannot
    #             follow. The archive is quietly out of date and, unlike a
    #             failure, will not fix itself on the next scan.
    def count_uningestable(document, item)
      if document.nil? || document.removed?
        counts[:skipped] += 1
      elsif document.source_version == item.version
        counts[:unchanged] += 1
      else
        counts[:stale] += 1
      end
    end

    # Re-ingest when:
    #   - the version token moved (the ordinary case);
    #   - a document we had tombstoned is back in the source — its token may well
    #     be unchanged, since a file restored from a backup keeps its mtime, but
    #     its chunks are gone;
    #   - the last attempt failed. This is what makes "the next sync retries it"
    #     true, and it is the reason these jobs need no ActiveJob retries: a
    #     failed document is picked up again on the next scan. Without it, a
    #     document whose ingest failed *after* its version was recorded would sit
    #     failed forever, because every later scan would call it unchanged.
    def changed?(document, item)
      document.source_version != item.version || document.removed? || document.failed?
    end

    def create_document(item, run)
      # Built off Document rather than the association, so an item that fails to
      # validate isn't left in source.documents for the next autosave to choke on.
      document = Document.new(source:, external_id: item.external_id, status: :pending, source_sync: run)
      document.assign_attributes(description(document, item))
      document.save!
      document
    end

    # source_version is intentionally *not* written here — ImportItemJob sets it
    # once the bytes are actually in hand. Until then the document still carries
    # the version it was last successfully ingested at, so an import that fails
    # is picked up again by the next scan rather than being recorded as done.
    def import(document, item)
      ImportItemJob.perform_later(document, item.version)
    end

    # Anything the source no longer reports has left it: tombstone
    # it and drop its chunks. Iterating our own documents and testing membership
    # of `seen` in Ruby, rather than a NOT IN over every external_id, keeps this
    # a constant-size query no matter how large the folder is.
    def tombstone_vanished(run)
      source.documents.where.not(status: :removed).find_each do |document|
        next if seen.include?(document.external_id)

        counts[:removed] += 1
        tombstone(document, run)
      end
    end

    def tombstone(document, run)
      document.transaction do
        document.chunks.destroy_all
        document.update!(status: :removed, source_sync: run)
        # Retract only the memberships this source asserted; a document a
        # human filed into a collection stays filed, tombstone or not.
        document.collection_memberships.active.feed.find_each(&:remove!)
      end
    end

    def finish(run, status:, error: nil)
      run.update!(
        status: status,
        finished_at: Time.current,
        error: error,
        found_count: counts[:found],
        created_count: counts[:created],
        updated_count: counts[:updated],
        unchanged_count: counts[:unchanged],
        removed_count: counts[:removed],
        skipped_count: counts[:skipped],
        stale_count: counts[:stale],
        failed_count: counts[:failed]
      )

      # Stamped even when the scan failed, so a source whose folder has been
      # unmounted waits out its interval before trying again instead of being
      # retried by the scheduler on every tick.
      source.update!(last_synced_at: Time.current)
    end
  end
end
