module Search
  class SearchN < Base
    def initialize(collections, num_results: 10, traceable: nil, include_irrelevant: false)
      @collections = collections
      @num_results = num_results || 10
      @traceable = traceable
      @include_irrelevant = include_irrelevant

      super()
    end

    def search(query, &)
      hits = searchers.map do |search|
        search.search(query)
      end.flatten.sort_by(&:distance)

      filter = Filters::DistanceRatio.new(hits)
      hits = @include_irrelevant ? filter.all : filter.filtered

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
