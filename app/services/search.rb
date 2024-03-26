class Search
  def initialize(collection, dom_id = nil, partial = "shared/chunk")
    @collection = collection
    @dom_id = dom_id
    @partial = partial
  end

  def search(query)
    embedded_query = embedder.embed(query)
    response = chroma.query(collection_id, [embedded_query])

    puts response

    results = []
    response["ids"].first.each_with_index do |id, index|
      chunk = chunk_for(id)

      yield chunk if block_given? and chunk.present?

      if @dom_id.present?
        distance = response["distances"].first[index]

        broadcast_chunk(chunk, distance) if chunk
      end

      results << chunk if chunk
    end

    results
  end

  private

  def broadcast_chunk(chunk, distance)
    Turbo::StreamsChannel.broadcast_append_to(
      :collection, target: @dom_id, partial: @partial, locals: { chunk:, distance: }
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
    @chrome ||= Chromadb::Client.new("localhost", 8000)
  end
end
