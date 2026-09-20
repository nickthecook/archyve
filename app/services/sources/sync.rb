module Sources
  # The sync engine. Diffs what a source currently reports against the
  # Documents it has already produced, and reconciles the difference.
  #
  # Deliberately knows nothing about folders, S3, or Bookstack. A source only
  # has to answer two questions — "what is there?" (#each_item, yielding items
  # with a stable external_id and a version token) and "give me this one's
  # bytes" (#read) — and it can be synced by this class unchanged.
  #
  # What it does *not* do is fetch or process anything: each changed item is
  # handed to Sources::ImportItemJob, so one unreadable file or one slow
  # download can't stall the scan or lose the rest of the diff.
  #
  # ## Scans that don't finish in one go
  #
  # A source whose enumeration is itself expensive — a crawl, where the next
  # item is only discovered by fetching the last one — can declare
  # `.resumable_scan?`. It is then given a wall-clock budget, and when that
  # expires the scan stops where it is, leaves the run `paused`, and the
  # scheduler resumes it on the next tick. Counts accumulate across passes;
  # nothing is tombstoned until a pass reaches the end of the source.
  #
  # Everything else is unaffected: a source that doesn't opt in is never
  # interrupted, so a folder and a wiki scan exactly as they always did.
  class Sync
    # How long one pass may run before it gives the worker back.
    #
    # Well inside SyncJob's `limits_concurrency` duration, which cannot be
    # extended from inside a running job — so a pass must finish rather than
    # renew its claim.
    #
    # Nothing is suspended: the job returns, its thread and semaphore are
    # released, and the run is picked up again by the next
    # Sources::EnqueueDueSyncsJob tick — a minute at most, since
    # `Source.mid_paused_scan` makes it due regardless of interval. A free
    # worker does not shorten that; the heartbeat is what enqueues. Worth
    # keeping the budget far longer than the tick, or the gap between passes
    # starts to rival the work done in them.
    BUDGET = 15.minutes

    # How often a running pass writes down where it has got to.
    #
    # This is what paces the counts on the source page, so it wants to be near
    # the 2.5s the progress controller polls at rather than near the stall
    # threshold — a long scan whose numbers move every half-minute reads as
    # stuck. One row-write per source per interval; the poll is happening
    # either way.
    PROGRESS_INTERVAL = 10.seconds

    # The run's tally columns, and the key each is kept under while scanning.
    # Read in both directions: seeded from the row when resuming a paused run,
    # written back to it on every pass, so the row always holds the total so far
    # rather than the last pass's delta.
    COUNT_COLUMNS = {
      "found_count" => :found,
      "created_count" => :created,
      "updated_count" => :updated,
      "unchanged_count" => :unchanged,
      "removed_count" => :removed,
      "skipped_count" => :skipped,
      "stale_count" => :stale,
      "failed_count" => :failed
    }.freeze

    def self.call(...) = new(...).call

    def initialize(source)
      @source = source
      @counts = Hash.new(0)
    end

    def call
      run = resume_or_start
      @deadline = BUDGET.from_now if source.resumable_scan?
      @progress_due = PROGRESS_INTERVAL.from_now

      begin
        case scan(run)
        when :drained
          tombstone_vanished(run)
          finish(run, status: :completed)
        when :paused
          finish(run, status: :paused)
        when :abandoned
          # Deliberately no `finish`: the run is not ours to write any more.
          # See #record_progress.
          return run.reload
        end
      rescue StandardError => e
        finish(run, status: :failed, error: "#{e.class}: #{e.message}")
        raise
      end

      run
    end

    private

    attr_reader :source, :counts

    # The run to reconcile against: whatever pass was left part-finished, or a
    # new one. Counts are seeded from the row so `finish` can go on writing
    # totals rather than deltas.
    def resume_or_start
      run = source.syncs.paused.recent.first

      if run
        counts.merge!(run.slice(*COUNT_COLUMNS.keys).to_h.transform_keys { |column| COUNT_COLUMNS.fetch(column) })
        run.update!(status: :running, last_progress_at: Time.current)
      else
        run = source.syncs.create!(started_at: Time.current, last_progress_at: Time.current)
      end

      run
    end

    # How the pass ended:
    #
    #   :drained    the source ran out of items — the only complete view of it,
    #               and so the only one allowed to tombstone
    #   :paused     the budget ran out first
    #   :abandoned  something retired this run while we were working
    #
    # Each of the two early exits is a `break` rather than an exception: it
    # leaves `each_item` through the source's own `ensure`, which is where a
    # resumable source persists the position it has reached. A pass that stands
    # down still wants its crawl position kept — the work was done, it is only
    # the run's bookkeeping that is no longer ours.
    def scan(run)
      outcome = :drained

      source.each_item do |item|
        # Checked before reconciling, not after: if we have been given up on,
        # the cheapest thing to do is stop writing immediately.
        unless record_progress(run)
          outcome = :abandoned
          break
        end

        counts[:found] += 1
        reconcile(item, run)

        if out_of_budget?
          outcome = :paused
          break
        end
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
        # The item goes unstamped, so it isn't tombstoned: an item we failed to
        # record is not an item we know to be gone.
        counts[:failed] += 1
        Rails.logger.error("Source #{source.id} failed on #{item.external_id}: #{e.class}: #{e.message}")
      end

      Rails.logger.warn("Sync of source #{source.id} stood down: run #{run.id} was retired") if outcome == :abandoned

      outcome
    end

    def reconcile(item, run)
      document = source.documents.find_by(external_id: item.external_id)

      # Present in the source but not ingestable — too large, or whatever a
      # future source decides it can't take. It is still stamped as seen, so it
      # is not tombstoned, and any document already built from it is left
      # exactly as it is. Tightening a limit must never delete documents.
      return count_uningestable(document, item, run) if item.skipped?

      if document.nil?
        counts[:created] += 1
        import(create_document(item, run), item)
      elsif changed?(document, item)
        counts[:updated] += 1
        document.update!(**description(document, item), source_sync: run, last_seen_sync: run)
        import(document, item)
      else
        counts[:unchanged] += 1
        redescribe(document, item, run)
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
    #
    # The stamp goes on regardless of whether anything else moved: this is the
    # branch almost every document takes on almost every scan, and an unstamped
    # document is a tombstoned one.
    def redescribe(document, item, run)
      changes = description(document, item).reject { |attribute, value| document.public_send(attribute) == value }
      changes[:last_seen_sync] = run unless document.last_seen_sync_id == run.id

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
    def count_uningestable(document, item, run)
      document&.update!(last_seen_sync: run) unless document&.last_seen_sync_id == run.id

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
      document = Document.new(source:, external_id: item.external_id, status: :pending,
        source_sync: run, last_seen_sync: run)
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

    # Anything the source no longer reports has left it: tombstone it and drop
    # its chunks.
    #
    # Asked of the stamp rather than a Set of external_ids held in memory, which
    # is what lets a scan spread over several passes still answer it — and keeps
    # a large source's scan from carrying every id it has ever seen. IS DISTINCT
    # FROM, not `where.not`: a document no scan has ever stamped has a NULL here,
    # and `NULL <> 5` is NULL, which would quietly exclude exactly the rows that
    # most need tombstoning.
    def tombstone_vanished(run)
      source.documents
        .where.not(status: :removed)
        .where("last_seen_sync_id IS DISTINCT FROM ?", run.id)
        .find_each do |document|
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
      attributes = tallies
      attributes["status"] = status
      attributes["error"] = error
      attributes["last_progress_at"] = Time.current
      attributes["finished_at"] = Time.current unless status == :paused

      run.update!(attributes)

      # Stamped even when the scan failed, so a source whose folder has been
      # unmounted waits out its interval before trying again instead of being
      # retried by the scheduler on every tick.
      #
      # Not for a pause, though: the interval governs how often a source is
      # re-examined, and a scan already underway is not a re-examination.
      # Stamping here would make the source sit out a full interval in the
      # middle of a scan it is part-way through.
      source.update!(last_synced_at: Time.current) unless status == :paused
    end

    def out_of_budget?
      @deadline && Time.current >= @deadline
    end

    # A heartbeat, so a run that has stopped moving can be told from one that is
    # merely long — and, in the same statement, the counts so far and the answer
    # to whether this pass is still the live one.
    #
    # The counts ride along because otherwise they reach the database only in
    # `finish`, and the source page reads them from the row. A pass that runs
    # for its whole budget would show zeros for fifteen minutes and then jump,
    # which is indistinguishable from nothing happening. It also means a run
    # that dies keeps the tally it got through instead of reporting none.
    #
    # The write is conditional on the run still being `running`, so a run
    # Sources::SweepStalledSyncsJob has already retired matches nothing and
    # reports zero rows changed. Returning false is how the scan learns it has
    # been given up on.
    #
    # That matters because the sweeper judges on this very timestamp, and the
    # one thing it cannot see is a pass wedged *inside* `#each_item` — a hung
    # fetch between yields reports no progress while its thread is alive and
    # well. Such a pass wakes up to find itself retired, its source already due
    # again and its `SyncJob` semaphore long expired, which is to say a second
    # pass may be running beside it. Standing down is the only safe move: two
    # scans reconciling one source race each other's tombstones.
    #
    # `update_all` rather than `update!` to skip the broadcast and leave
    # `updated_at` alone. This is not a change to the run; it is proof someone
    # is still holding it.
    def record_progress(run)
      return true if Time.current < @progress_due

      @progress_due = PROGRESS_INTERVAL.from_now

      SourceSync.where(id: run.id, status: :running)
        .update_all(tallies.merge("last_progress_at" => Time.current)) == 1
    end

    def tallies = COUNT_COLUMNS.to_h { |column, key| [column, counts[key]] }
  end
end
