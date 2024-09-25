class EmbedChunk
  def initialize(chunk)
    @chunk = chunk
    @document = @chunk.document
  end

  def execute
    return if @document.stop_jobs

    initialize_collection

    embed
  end

  private

  def embed
    embedding = embedder.embed(@chunk.embedding_content)

    ids = chromadb.add_documents(@collection_id, [@chunk.content], [embedding])
    @chunk.update!(vector_id: ids.first)

    @document.touch(:updated_at)
  end

  def initialize_collection
    # this causes chromadb to print a pretty big stack trace; use /collections instead
    @collection_id = chromadb.collection_id(collection_name)

    if @collection_id.nil?
      response = chromadb.create_collection(collection_name, { creator: "archyve" })
      @collection_id = response["id"]
    end

    @collection_id
  end

  def collection_name
    @document.collection.slug
  end

  def embedder
    @embedder ||= Embedder.new(model_config: embedding_model, traceable: @chunk)
  end

  def embedding_model
    @document.collection.embedding_model
  end

  def chromadb
    @chromadb ||= Chromadb::Client.new(traceable: @chunk)
  end
end
