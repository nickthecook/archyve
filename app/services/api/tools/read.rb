# frozen_string_literal: true

module Api
  module Tools
    class Read < Base
      mirrors ::Tools::Read
      describe "Read a run of chunks from one document, in document order, " \
               "at most #{Retrieval::Read::MAX_CHUNKS} at a time."

      def execute(document:, from: nil, to: nil)
        reading = Retrieval::Read.new(corpus:).call(document, from:, to:)

        case reading.refusal
        when nil then ok(body(reading))
        when :not_found then not_found("document")
        when :not_processed
          error(:conflict, "not_processed", "This document hasn't been processed yet, so it has no text.")
        else
          error(:unprocessable_content, "out_of_range", "That document has #{reading.total} chunks.",
            total: reading.total)
        end
      end

      private

      def body(reading)
        {
          document: document_ref(reading.document),
          from: reading.from, to: reading.to, total: reading.total,
          chunks: reading.hits.map { chunk(it) }
        }
      end

      def chunk(hit)
        { chunk: hit.chunk.position + 1, section: hit.heading_path.presence, text: hit.chunk.content }.compact
      end
    end
  end
end
