class Search
  def initialize(collection)
    @collection = collection
  end

  def search(query, dom_id)
    embedded_query = embedder.embed(query)
    response = chroma.query(collection_id, [embedded_query])
    
    puts response

    chunks_for(response["ids"].first).each do |chunk|
      Turbo::StreamsChannel.broadcast_append_to(
        "collection", target: dom_id, partial: "shared/chunk", locals: { chunk:}
      )
    end
  end

  private

  def chunks_for(ids)
    ids.map do |id|
      chunk = Chunk.find_by(vector_id: id)

      if chunk.present?
        Rails.logger.info("Got hit for chunk #{id} in collection #{@collection.slug}.")
      else
        Rails.logger.warn(
          "Could not find chunk with id #{id} while searching collection #{@collection.slug} (#{@collection.id})."
        )
      end

      chunk
    end
  end

  def collection_id
    chroma.collection_id(@collection.slug)
  end

  def embedder
    @embedder ||= Embedder.new
  end

  def chroma
    @chrome ||= Chromadb::Client.new("localhost", 8000)
  end
end
