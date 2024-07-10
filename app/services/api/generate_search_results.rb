module Api
  class GenerateSearchResults
    def initialize(collections, base_url: nil, browser_base_url: nil, num_results: 20, traceable: nil)
      @collections = collections
      @base_url = base_url
      @browser_base_url = browser_base_url
      @num_results = num_results
      @traceable = traceable
    end

    def search(query)
      results = searcher.search(query)

      results.first(@num_results).map do |hit|
        SearchResult.new(hit, @base_url, @browser_base_url)
      end.map(&:to_h)
    end

    def searcher
      @searcher ||= ::Search::SearchN.new(
        @collections,
        num_results: @num_results,
        traceable: @traceable,
        include_irrelevant: @include_irrelevant
      )
    end
  end
end
