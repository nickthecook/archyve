module Search
  class SearchN < Base
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

      filtered_hits = filter(hits)
      hits = filtered_hits unless @include_irrelevant

      hits.first(@num_results).each(&)
    end

    private

    def filter(hits)
      filtered_list = hits

      filter_classes.each do |filter_class|
        filter = filter_class.new(filtered_list)
        filtered_list = filter.filtered
      end

      filtered_list
    end

    def filter_classes
      @filter_classes ||= [Filters::DistanceRatio, Filters::DistanceCeiling]
    end

    def searchers
      @searchers ||= @collections.map do |collection|
        Search.new(collection, traceable: @traceable)
      end
    end
  end
end
