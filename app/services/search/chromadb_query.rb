module Search
  class ChromadbQuery
    def initialize(collection, query, traceable: nil)
      @collection = collection
      @query = query
      @traceable = traceable
    end

    def results
      @results ||= fetch_results.sort_by!(&:distance)
    end

    private

    def fetch_results
      results = []

      response["ids"].first.each_with_index do |_id, index|
        reference = reference_for(index)
        next if reference.nil?

        results << SearchHit.new(reference, distance_for(index), previous_distance_for(index))
      end

      results
    end

    def reference_for(index)
      vector_id = response.dig("ids", 0, index)
      reference = reference_class_for_index(index).find_by(vector_id:)

      if reference.present?
        Rails.logger.info("Got hit for reference #{vector_id} in collection #{@collection.slug}.")
      else
        Rails.logger.error(
          "Could not find reference with id #{vector_id} while searching collection #{@collection.slug}."
        )
      end

      reference
    end

    def reference_class_for_index(index)
      reference_class_name = response.dig("metadatas", 0, index, "type")

      case reference_class_name
      when "entity_summary"
        GraphEntity
      when nil
        Chunk
      end
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
