module Search
  class SearchMultiple < Base
    def initialize(collections, num_results: 10, traceable: nil, include_irrelevant: false)
      @collections = collections
      @num_results = num_results
      @traceable = traceable
      @include_irrelevant = include_irrelevant

      super()
    end

    def search(query, &)
      hits = searchers.map do |search|
        search.search(query)
      end.flatten.sort_by(&:distance)

      hits.first(@num_results).each(&)
    end

    private

    def searchers
      @searchers ||= @collections.map do |collection|
        Search.new(collection, traceable: @traceable, include_irrelevant: @include_irrelevant)
      end
    end
  end
end
