module Search
  class SearchMultiple < Base
    def initialize(collections, num_results: 10, traceable: nil)
      @collections = collections
      @num_results = num_results
      @traceable = traceable

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
        Search.new(collection, traceable: @traceable)
      end
    end
  end
end
