module Search
  class SearchMultiple < Base
    def initialize(collections, dom_id: nil, partial: "collections/search_chunk", num_results: 20)
      @collections = collections
      @dom_id = dom_id
      @partial = partial
      @num_results = num_results

      super()
    end

    def search(query)
      hits = searchers.map do |search|
        search.search(query)
      end.flatten.sort_by(&:distance)

      hits.first(@num_results).each do |hit|
        Turbo::StreamsChannel.broadcast_append_to(
          "collection",
          target: @dom_id,
          partial: @partial,
          locals: { chunk: hit.chunk, distance: hit.distance }
        )
      end
    end

    def searchers
      @searchers ||= @collections.map do |collection|
        Search.new(collection)
      end
    end
  end
end
