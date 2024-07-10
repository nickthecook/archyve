module Search
  class ChromadbQuery
    def initialize(collection, query)
      @collection = collection
      @query = query
    end

    def results
      @results ||= fetch_results.sort_by!(&:distance)
    end

    private

    def fetch_results
      results = []

      response["ids"].first.each_with_index do |id, index|
        chunk = chunk_for(id)
        next if chunk.nil?

        results << SearchHit.new(chunk, distance_for(index), previous_distance_for(index))
      end

      results
    end

    def chunk_for(id)
      chunk = Chunk.find_by(vector_id: id)

      if chunk.present?
        Rails.logger.info("Got hit for chunk #{id} in collection #{@collection.slug}.")
      else
        Rails.logger.error("Could not find chunk with id #{id} while searching collection #{@collection.slug}.")
      end

      chunk
    end

    def distance_for(index)
      response["distances"].first[index]
    end

    def previous_distance_for(index)
      distance_for(index - 1) if index.positive?
    end

    def response
      @response ||= chroma.query(collection_id, [@query])
    end

    def collection_id
      chroma.collection_id(@collection.slug)
    end

    def chroma
      @chroma ||= Chromadb::Client.new(traceable: @traceable)
    end
  end
end
