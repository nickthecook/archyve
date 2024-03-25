class Search
  def initialize(collection)
    @collection = collection
  end

  def search(query, dom_id)
    embedded_query = embedder.embed(query)
    response = chroma.query(collection_id, [embedded_query])
    
    puts response

    response["ids"].first.each_with_index do |id, index|
      chunk = chunk_for(id)
      distance = response["distances"].first[index]

      Turbo::StreamsChannel.broadcast_append_to(
        "collection", target: dom_id, partial: "shared/chunk", locals: { chunk:, distance: }
      )
    end
  end

  private

  def chunk_for(id)
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
