module Graph
  class VectorizeCollectionSummaries
    def initialize(collection)
      @collection = collection
    end

    def execute
      initialize_collection

      @collection.graph_entities.map do |entity|
        embedding = embedder.embed(entity.summary)
        id = chromadb.add_entity_summary(@collection_id, entity.summary, embedding)
        entity.update!(vector_id: id)
      end
    end

    private

    def initialize_collection
      # this causes chromadb to print a pretty big stack trace; use /collections instead
      collection_id = chromadb.collection_id(@collection.slug)

      if collection_id.nil?
        response = chromadb.create_collection(@collection.slug, { creator: "archyve" })
        collection_id = response["id"]
      end

      @collection_id = collection_id
    end

    def chromadb
      @chromadb ||= Chromadb::Client.new(traceable: @collection)
    end

    def embedder
      @embedder ||= Embedder.new(model_config: embedding_model, traceable: @collection)
    end

    def embedding_model
      @collection.embedding_model
    end
  end
end
