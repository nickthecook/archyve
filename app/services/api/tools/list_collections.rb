# frozen_string_literal: true

module Api
  module Tools
    class ListCollections < Base
      mirrors ::Tools::ListCollections
      describe "List the collections you can read: what each is for, how many documents it holds, " \
               "and which sources feed it."

      def execute
        listing = Retrieval::List.new(corpus:).collections
        ok(collections: listing.entries, total: listing.total)
      end
    end
  end
end
