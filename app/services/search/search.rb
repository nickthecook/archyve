module Search
  class Search < Base
    def initialize(collection, traceable: nil, include_irrelevant: false)
      @collection = collection
      @traceable = traceable
      @include_irrelevant = include_irrelevant

      super()
    end

    def search(query)
      raise SearchError, "No query given" if query.blank?

      embedded_query = embedder.embed(query)
      results = chroma_results_for(embedded_query)

      results.each do |result|
        yield result if block_given?
      end

      results
    end

    private

    def chroma_results_for(query)
      ChromadbQuery.new(@collection, query, traceable: @traceable).results
    end

    def embedder
      @embedder ||= Embedder.new(@collection.embedding_model, traceable: @traceable)
    end
  end
end
