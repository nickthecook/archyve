require "digest"

module Ingestion
  # Entry point for the manual_upload connector: takes a user's uploaded file,
  # creates a Document owned by the shared manual_upload connector, attaches the
  # bytes, optionally adds it to collections, and enqueues the pipeline.
  #
  # The document's external_id is the file's content hash, so re-uploading the
  # exact same bytes is idempotent — it returns the existing Document instead of
  # ingesting a duplicate (mirrors the connector sync "skip unchanged" rule).
  #
  # No rescue here on purpose: everything that can raise is a real bug or outage
  # the caller (a controller) should surface. Expected pipeline failures (Docling
  # down, embedding errors) are handled in ProcessDocumentJob.
  class DocumentUploader
    CONNECTOR_NAME = "Manual Upload".freeze

    def self.call(...) = new(...).call

    def initialize(file:, filename: nil, content_type: nil, collections: [])
      @file = file
      @filename = filename || file.try(:original_filename) || "upload"
      @content_type = content_type || file.try(:content_type) || "application/octet-stream"
      @collections = Array(collections)
    end

    def call
      document = connector.documents.find_or_initialize_by(external_id: checksum)
      return document unless document.new_record? # identical bytes already ingested

      # DB writes commit atomically; Rails 8 enqueues after commit, so the job
      # never fires for a document that rolled back.
      document.transaction do
        document.assign_attributes(title: @filename, content_type: @content_type, status: :pending)
        document.file.attach(io: StringIO.new(bytes), filename: @filename, content_type: @content_type)
        document.save!
        add_to_collections(document)
      end

      ProcessDocumentJob.perform_later(document)
      document
    end

    private

    def connector
      @connector ||= Connectors::ManualUpload.first_or_create!(name: CONNECTOR_NAME)
    end

    def add_to_collections(document)
      @collections.each do |collection|
        membership = document.collection_memberships.find_or_initialize_by(collection: collection)
        membership.update!(source: :manual, removed_at: nil)
      end
    end

    def checksum
      @checksum ||= Digest::SHA256.hexdigest(bytes)
    end

    # Read once, into memory. Fine for now (uploads are small); revisit with
    # streaming if we start ingesting very large files.
    def bytes
      @bytes ||= begin
        @file.rewind if @file.respond_to?(:rewind)
        @file.read
      end
    end
  end
end
