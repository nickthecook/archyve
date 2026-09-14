require "digest"

module Ingestion
  # Entry point for manual upload: takes a user's uploaded file, creates a
  # Document owned by *that user's own* upload source, attaches the bytes,
  # optionally adds it to collections, and enqueues the pipeline.
  #
  # One upload source per person, not one for the whole install. A shared
  # singleton made manual upload the odd type out — every other source has an
  # owner who manages it — and left nobody able to own their own uploads.
  #
  # The document's external_id is the file's content hash, so re-uploading the
  # exact same bytes is idempotent — it returns the existing Document instead of
  # ingesting a duplicate (mirrors the source sync "skip unchanged" rule).
  # Note that dedup is now per-uploader: two people uploading identical bytes
  # get a document each. That is the honest reading of ownership — one person
  # deleting their upload must not delete another's — and unlike per-collection
  # duplication it doesn't multiply with membership.
  #
  # No rescue here on purpose: everything that can raise is a real bug or outage
  # the caller (a controller) should surface. Expected pipeline failures (Docling
  # down, embedding errors) are handled in ProcessDocumentJob.
  class DocumentUploader
    def self.call(...) = new(...).call

    # `ocr` is the uploader's own answer for this file, stored on the document
    # so a reprocess months later does the same thing this upload did. nil
    # leaves it to the source, which is what a caller that wasn't asked should
    # pass rather than guessing a default.
    def initialize(file:, user:, filename: nil, content_type: nil, collections: [], ocr: nil)
      @file = file
      @user = user
      @filename = filename || file.try(:original_filename) || "upload"
      @content_type = content_type || file.try(:content_type) || "application/octet-stream"
      @collections = Array(collections)
      @ocr = ocr
    end

    def call
      document = source.documents.find_or_initialize_by(external_id: checksum)

      # Identical bytes already ingested: don't re-ingest, but still honour the
      # requested collections so "upload to this collection" works even when the
      # file already exists elsewhere in the archive.
      unless document.new_record?
        add_to_collections(document)
        return document
      end

      # DB writes commit atomically; Rails 8 enqueues after commit, so the job
      # never fires for a document that rolled back.
      document.transaction do
        document.assign_attributes(title: @filename, content_type: @content_type, status: :pending, ocr: @ocr)
        document.file.attach(io: StringIO.new(bytes), filename: @filename, content_type: @content_type)
        document.save!
        add_to_collections(document)
      end

      ProcessDocumentJob.perform_later(document)
      document
    end

    private

    # The uploader's own source, created on their first upload. Named for them
    # so the sources list reads as a list of owners; the name is a snapshot, not
    # a derived value, so a later email change doesn't rewrite history.
    def source
      @source ||= Sources::ManualUpload.create_with(name: "Uploads — #{@user.email_address}")
        .find_or_create_by!(user: @user)
    end

    # Use the user-path add so an existing feed membership is never illegally
    # downgraded (CollectionMembership.add is a no-op on an active feed row).
    def add_to_collections(document)
      @collections.each { |collection| CollectionMembership.add(document:, collection:) }
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
