class TheIngestor
  def initialize(document)
    @document = document
    @chunks = []
  end

  def ingest
    ensure_collection_exists

    @chunks = chonker.chunks.map { |chunk| Chunk.new(document: @document, content: chunk)}

    ## save all chunks to the db
    @document.transaction do
      @chunks.each(&:save!)

      @document.chunked!
    end

    @chunks.each do |chunk|
      embedding = embedder.embed(chunk)
      ids = chromadb.add_documents(@collection_id, [chunk.content], [embedding])
      chunk.update!(vector_id: ids.first)
    end
  end

  private

  def ensure_collection_exists
    if @document.created?
      initialize_collection
    else
      reset_document
    end
  end

  def reset_document
    # remove all docs from collection in chroma
    @collection_id = chromadb.empty_collection(collection_name)

    # remove all local chunks from db
    @document.chunks.destroy_all

    # set the document's state back to created
    @document.reset!
  end

  def parser
    @parser ||= DocumentParser.new(@document)
  end

  def chonker
    @chonker ||= Chonker.new(parser, :bytes)
  end

  def embedder
    @embedder ||= Embedder.new(embedding_endpoint)
  end

  def embedding_endpoint
    "http://shard:11434"
  end

  def chromadb
    @chromadb ||= Chromadb::Client.new("localhost", 8000)
  end

  def collection_name
    @document.collection.slug
  end

  def initialize_collection
    collection_id = chromadb.collection_id(collection_name)

    if collection_id.nil?
      response = chromadb.create_collection(collection_name, { creator: "archyve" })
      collection_id = response["id"]
    end

    @collection_id = collection_id
  end
end
