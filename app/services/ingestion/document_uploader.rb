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
        rerun_if_this_upload_asked_for_something_new(document)
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

    # Re-uploading bytes the archive already holds is not necessarily a no-op.
    # The *file* is the same; this upload's answers about it may not be, and
    # somebody uploading a document they already uploaded is usually asking for
    # a different result than they got last time.
    #
    # Two triggers, and deliberately only these:
    #
    #   the OCR choice differs from the one that produced the chunks we hold —
    #     keeping them would leave the page claiming a setting the content
    #     doesn't reflect
    #   the last run failed — re-uploading is the obvious "try again", and
    #     until now it quietly did nothing while the flash said "Processing…"
    #
    # A re-upload of a document that processed cleanly under the same settings
    # stays the cheap no-op it has always been. Reprocessing it would spend
    # minutes of docling to arrive back where it started.
    def rerun_if_this_upload_asked_for_something_new(document)
      return unless ocr_changed?(document) || document.failed?

      document.ocr = @ocr unless @ocr.nil?
      # Saves the OCR change along with the status, and clears the previous
      # run's verdict so the page doesn't show a stale diagnosis as current.
      document.queue_for_processing!
      ProcessDocumentJob.perform_later(document)
    end

    # Compared against `ocr?`, not the raw column: a document inheriting `true`
    # from its source has not been asked to change when this upload also says
    # true, even though the column reads nil.
    def ocr_changed?(document)
      !@ocr.nil? && @ocr != document.ocr?
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
