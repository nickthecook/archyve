require "digest"

module Connectors
  # Brings one item's bytes into the archive: read from the source, attach, file
  # it into the connector's collections, and hand it to the ingestion pipeline.
  #
  # One job per item so a single unreadable file fails alone, and so fetching
  # (a network call for most connectors) happens on a worker rather than inside
  # the scan.
  class ImportItemJob < ApplicationJob
    queue_as :ingestion

    # Serialize per document, for the same reason ProcessDocumentJob does: a
    # re-import enqueued while the previous one is still attaching would race on
    # the attachment. The concurrency group defaults to the job class name, so
    # this lock is distinct from ProcessDocumentJob's on the same document.
    limits_concurrency key: ->(document, _version) { document.id }, to: 1, duration: 15.minutes

    def perform(document, version)
      bytes = document.connector.read(document.external_id)
      checksum = Digest::SHA256.hexdigest(bytes)

      if unchanged?(document, checksum)
        # The version token moved but the content didn't — a `touch`, a restored
        # backup, a rewritten mtime. Record the new token so the next scan stops
        # seeing it as changed, and skip the pipeline: re-extracting and
        # re-embedding identical bytes is the expensive mistake this avoids.
        document.update!(source_version: version)
        return
      end

      attach(document, bytes, checksum)
      feed_collections(document)
      ProcessDocumentJob.perform_later(document)

      # Written last, and on its own: source_version means "this version was
      # fully handed off to the pipeline", so anything that fails before this
      # line leaves the old token in place and the next scan tries again. Dying
      # between the enqueue and here is harmless — the re-import is idempotent.
      document.update!(source_version: version)
    rescue StandardError => e
      document.update!(status: :failed) if document.persisted?
      Rails.logger.error("ImportItemJob failed for document #{document.id}: #{e.class}: #{e.message}")
      raise
    end

    private

    # Only skip when we have a processed document to skip *to*. A document whose
    # content matches but whose last pipeline run failed still needs processing.
    def unchanged?(document, checksum)
      document.processed? && document.source_metadata["checksum"] == checksum
    end

    def attach(document, bytes, checksum)
      document.transaction do
        # Attaching to a has_one_attached replaces what was there and purges the
        # old blob on its own; purging first would delete the bytes even if this
        # transaction went on to roll back.
        document.file.attach(
          io: StringIO.new(bytes),
          filename: File.basename(document.external_id),
          content_type: document.content_type || "application/octet-stream"
        )
        document.update!(
          status: :pending,
          source_metadata: document.source_metadata.merge("checksum" => checksum, "byte_size" => bytes.bytesize)
        )
      end
    end

    # Documents a connector produces join the collections it feeds. `feed!` is
    # the system path: it claims or restores the connector's own row and never
    # touches a membership a human made.
    def feed_collections(document)
      document.connector.fed_collections.each do |collection|
        CollectionMembership.feed!(document: document, collection: collection)
      end
    end
  end
end
