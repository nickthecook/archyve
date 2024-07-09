module Search
  class Search < Base
    DISTANCE_RATIO_THRESHOLD = 0.2

    def initialize(collection, traceable: nil, include_irrelevant: false)
      @collection = collection
      @traceable = traceable
      @include_irrelevant = include_irrelevant

      super()
    end

    def search(query)
      raise SearchError, "No query given" if query.blank?

      embedded_query = embed(query)
      @response = chroma_response(collection_id, embedded_query)
      Rails.logger.debug { "ChromaDB response:\n#{@response.to_json}" }

      results = process_response
      results.each do |result|
        yield result if block_given?
      end

      results
    end
    # rubocop:enable all

    private

    def process_response
      results = []

      @response["ids"].first.each_with_index do |id, index|
        chunk = chunk_for(id)
        next if chunk.nil?

        results << SearchHit.new(chunk, distance_for(index), previous_distance_for(index))
      end

      results.sort_by!(&:distance)
      mark_relevance(results)

      @include_irrelevant ? results : results.filter(&:relevant)
    end

    def mark_relevance(hits)
      still_relevant = true

      hits.each do |hit|
        if still_relevant && hit.distance_increase_ratio > distance_ratio_threshold
          still_relevant = false
        end

        hit.relevant = still_relevant
      end
    end

    def distance_for(index)
      @response["distances"].first[index]
    end

    def previous_distance_for(index)
      distance_for(index - 1) if index.positive?
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

    def distance_ratio_threshold
      @distance_ratio_threshold || Setting.get("distance_ratio_threshold", default: DISTANCE_RATIO_THRESHOLD)
    end
  end
end
