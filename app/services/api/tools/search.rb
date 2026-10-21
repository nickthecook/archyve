# frozen_string_literal: true

module Api
  module Tools
    class Search < Base
      mirrors ::Tools::Search
      describe "Search the archive for passages relevant to one or more queries, best match first."
      params(
        queries: { minItems: 1, maxItems: ::Tools::Search::MAX_QUERIES },
        collections: {
          type: "array", items: { type: "string" },
          description: "Slugs of the collections to search. Defaults to everything you can read."
        },
        limit: {
          type: "integer", minimum: 1, maximum: Retrieval::Search::DEFAULT_LIMIT,
          description: "How many passages to return, at most #{Retrieval::Search::DEFAULT_LIMIT}."
        }
      )

      def execute(queries:, collections: nil, limit: Retrieval::Search::DEFAULT_LIMIT)
        outcome = Retrieval::Search.new(corpus: corpus(scope: scope(collections))).call(queries, limit:)
        return unavailable(outcome.failure) if outcome.failed?

        totals = chunk_totals(outcome.hits)
        ok(results: outcome.hits.map { result(it, totals) })
      end

      private

      def scope(slugs) = slugs && Retrieval::Scope.new(user:, slugs:)

      def result(hit, totals)
        {
          document: document_ref(hit.document),
          chunk: hit.chunk.position + 1,
          chunks: totals[hit.document.id],
          section: hit.heading_path.presence,
          similarity: hit.similarity,
          text: hit.chunk.content
        }.compact
      end

      def chunk_totals(hits)
        Chunk.where(document_id: hits.map { it.document.id }.uniq).group(:document_id).count
      end

      def unavailable(failure)
        error(:service_unavailable, "retrieval_unavailable", "The archive could not be searched.",
          reason: failure.kind.to_s)
      end
    end
  end
end
