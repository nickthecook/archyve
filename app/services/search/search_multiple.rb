module Search
  class SearchMultiple < Base
    def initialize(collections, num_results: 10)
      @collections = collections
      @num_results = num_results

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
        Search.new(collection)
      end
    end
  end
end
