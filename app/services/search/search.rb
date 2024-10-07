module Search
  class Search
    def initialize(collection, traceable: nil, include_irrelevant: false)
      @collection = collection
      @traceable = traceable
      @include_irrelevant = include_irrelevant

      super()
    end

    def search(query)
      raise SearchError, "No query given" if query.blank?

      embedded_query = embedder.embed(query)
      results = chroma_response_for(embedded_query)
      normalizer.normalize!(results)

      results.each do |result|
        yield result if block_given?
      end

      results
    end

    private

    def normalizer
      @normalizer ||= DistanceNormalizer.new(@collection.embedding_model)
    end

    def chroma_response_for(query)
      ChromadbQuery.new(@collection, query, traceable: @traceable).results
    end

    def embedder
      @embedder ||= Embedder.new(model_config: @collection.embedding_model, traceable: @traceable)
    end
  end
end
