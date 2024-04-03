module Search
  class Search < Base
    def initialize(collection, dom_id: nil, partial: "shared/chunk", channel: :collection)
      @collection = collection
      @dom_id = dom_id
      @partial = partial
      @channel = channel

      super()
    end

    def search(query)
      raise SearchError, "No query given" if query.blank?

      embedded_query = embedder.embed(query)
      response = chroma.query(collection_id, [embedded_query])

      Rails.logger.info("ChromaDB response:\n#{response.to_json}")

      results = []
      response["ids"].first.each_with_index do |id, index|
        chunk = chunk_for(id)
        next if chunk.nil?

        hit = SearchHit.new(chunk, response["distances"].first[index])

        yield hit if block_given?

        broadcast_hit(hit) if @dom_id.present?

        results << hit
      end

      results.sort_by(&:distance)
    end

    private

    def broadcast_hit(hit)
      Turbo::StreamsChannel.broadcast_append_to(
        @channel, target: @dom_id, partial: @partial, locals: { chunk: hit.chunk, distance: hit.distance }
      )
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
      @embedder ||= Embedder.new
    end

    def chroma
      @chroma ||= Chromadb::Client.new
    end
  end
end
