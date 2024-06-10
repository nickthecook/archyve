module Api
  class SearchMultiple
    def initialize(collections, base_url: nil, browser_base_url: nil, num_results: 20)
      @collections = collections
      @base_url = base_url
      @browser_base_url = browser_base_url
      @num_results = num_results
    end

    def search(query)
      results = searchers.map do |search|
        search.search(query)
      end.flatten

      results.sort_by! { |result| result[:distance] }

      results.first(@num_results)
    end

    def searchers
      @searchers ||= @collections.map do |collection|
        Search.new(collection, base_url: @base_url, browser_base_url: @browser_base_url)
      end
    end
  end
end
