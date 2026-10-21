# frozen_string_literal: true

module Api
  module Tools
    class ListDocuments < Base
      mirrors ::Tools::ListDocuments
      describe "List the documents in one collection by title, " \
               "at most #{Retrieval::List::MAX_DOCUMENTS} at a time."
      params(
        from: { minimum: 1 },
        limit: { minimum: 1, maximum: Retrieval::List::MAX_DOCUMENTS }
      )

      def execute(collection:, from: nil, limit: nil)
        listing = Retrieval::List.new(corpus:).documents(collection, from:, limit:)
        return not_found("collection") if listing.refused?

        ok(
          collection: listing.title,
          from: listing.from, to: listing.to, total: listing.total,
          documents: listing.entries
        )
      end
    end
  end
end
