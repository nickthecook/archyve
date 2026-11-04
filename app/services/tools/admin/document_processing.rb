# frozen_string_literal: true

module Tools
  module Admin
    class DocumentProcessing < Base
      STUCK_AFTER = 30.minutes
      DETAIL_LIMIT = 300

      params do
        integer :limit, description: "How many failed and stuck documents to show, up to #{MAX_LIMIT}. Defaults to 10.",
          required: false
      end

      def name = "check_document_processing"
      def label = "document processing"

      def description
        "Count documents by processing status, and list the most recent failures with the stage and reason " \
          "each failed, plus any document that has been processing for over #{STUCK_AFTER.inspect}."
      end

      def execute(limit: nil)
        limit = capped(limit, default: 10)

        {
          status: "ok",
          by_status: Document.group(:status).count.map { |status, count| "#{status} #{count}" }.join(", ").presence || "no documents",
          failed: Document.failed.includes(:source).order(updated_at: :desc).limit(limit).map { failure(it) }.presence || "none",
          stuck: stuck.includes(:source).order(:updated_at).limit(limit).map { stuck_entry(it) }.presence || "none"
        }
      end

      private

      def stuck = Document.processing.where(updated_at: ...STUCK_AFTER.ago)

      def failure(document)
        {
          id: document.id, title: document.title, source: document.source.name,
          stage: document.outcome_stage, reason: document.outcome_kind,
          detail: document.outcome_detail&.truncate(DETAIL_LIMIT), at: document.updated_at.iso8601
        }.compact
      end

      def stuck_entry(document)
        { id: document.id, title: document.title, source: document.source.name, since: document.updated_at.iso8601 }
      end
    end
  end
end
