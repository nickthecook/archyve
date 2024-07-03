module Search
  class Search < Base
    def initialize(collection, traceable: nil)
      @collection = collection
      @traceable = traceable

      super()
    end

    def search(query)
      raise SearchError, "No query given" if query.blank?

      embedded_query = embed(query)
      response = chroma_response(collection_id, embedded_query)
      Rails.logger.debug { "ChromaDB response:\n#{response.to_json}" }

      results = process_response(response)
      results.each do |result|
        yield result if block_given?
      end

      results
    end
    # rubocop:enable all

    private

    def process_response(response)
      results = []

      response["ids"].first.each_with_index do |id, index|
        chunk = chunk_for(id)
        next if chunk.nil?

        results << SearchHit.new(chunk, response["distances"].first[index])
      end

      results.sort_by(&:distance)
    end

    def embed(query)
      embedder.embed(query)
    end

    def chroma_response(collection_id, query)
      chroma.query(collection_id, [query])
    end

    def chunk_for(id)
      chunk = Chunk.find_by(vector_id: id)

      if chunk.present?
        Rails.logger.info("Got hit for chunk #{id} in collection #{@collection.slug}.")
      else
        Rails.logger.warn("Could not find chunk with id #{id} while searching collection #{@collection.slug}.")
      end

      chunk
    end

    def collection_id
      chroma.collection_id(@collection.slug)
    end

    def embedder
      @embedder ||= Embedder.new(@collection.embedding_model, traceable: @traceable)
    end

    def chroma
      @chroma ||= Chromadb::Client.new(traceable: @traceable)
    end
  end
end
