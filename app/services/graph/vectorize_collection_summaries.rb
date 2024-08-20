module Graph
  class VectorizeCollectionSummaries
    def initialize(collection)
      @collection = collection
    end

    def execute
      initialize_collection

      vectorize_collection

      @collection.update!(state: "vectorized") unless @collection.stopped?
    rescue StandardError => e
      Rails.logger.error("#{e.class.name}: #{e.message}#{e.backtrace.join("\n")}")
      @collection.update!(state: :errored)

      raise e
    end

    private

    def vectorize_collection
      @collection.update!(state: "vectorizing", process_steps: entities.count)
      entities.each_with_index do |entity, index|
        @collection.update!(process_step: index + 1)

        embedding = embedder.embed(entity.summary, traceable: entity)
        id = chromadb.add_entity_summary(@collection_id, entity.summary, embedding)
        entity.update!(vector_id: id)

        if @collection.reload.stop_jobs
          @collection.update!(state: :stopped)
          break
        end
      end
    end

    def initialize_collection
      # this causes chromadb to print a pretty big stack trace; use /collections instead
      collection_id = chromadb.collection_id(@collection.slug)

      if collection_id.nil?
        response = chromadb.create_collection(@collection.slug, { creator: "archyve" })
        collection_id = response["id"]
      end

      @collection_id = collection_id
    end

    def entities
      @entities ||= @collection.graph_entities
    end

    def chromadb
      @chromadb ||= Chromadb::Client.new(traceable: @collection)
    end

    def embedder
      @embedder ||= Embedder.new(model_config: embedding_model)
    end

    def embedding_model
      @collection.embedding_model
    end
  end
end
