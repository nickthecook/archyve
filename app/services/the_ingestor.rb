class TheIngestor
  def initialize(document)
    @document = document
    @chunks = []
  end

  def ingest
    ensure_collection_exists

    @document.chunking!
    @chunks = chonker.chunks.map { |chunk| Chunk.new(document: @document, content: chunk) }
    Rails.logger.info("Got #{@chunks.count} chunks from #{@document.filename}.")

    ## save all chunks to the db
    @document.transaction do
      @chunks.each(&:save!)
    end
    @document.chunked!

    @document.embedding!
    @chunks.each_with_index do |chunk, idx|
      Rails.logger.info("Embedding chunk #{chunk.id} (#{idx}/#{@chunks.count})...")
      embedding = embedder.embed(chunk.content)
      ids = chromadb.add_documents(@collection_id, [chunk.content], [embedding])
      chunk.update!(vector_id: ids.first)
    end
    @document.embedded!
  rescue StandardError => e
    Rails.logger.error("Error ingesting document #{@document.id}\n#{e.class.name}: #{e.message}#{e.backtrace.join("\n")}")
    @document.error!

    raise e
  end

  private

  def ensure_collection_exists
    if @document.created?
      initialize_collection
    else
      Rails.logger.warn("RESETTING DOCUMENT #{@document.id}: is in state #{@document.state}...")
      reset_document
    end
  end

  def parser
    @parser ||= Parsers.parser_for(@document.filename).new(@document)
  end

  def chonker
    @chonker ||= Chonker.new(parser)
  end

  def embedder
    @embedder ||= Embedder.new(embedding_model)
  end

  def embedding_model
    @document.collection.embedding_model
  end

  def chromadb
    @chromadb ||= Chromadb::Client.new
  end

  def collection_name
    @document.collection.slug
  end

  def initialize_collection
    # this causes chromadb to print a pretty big stack trace; use /collections instead
    collection_id = chromadb.collection_id(collection_name)

    if collection_id.nil?
      response = chromadb.create_collection(collection_name, { creator: "archyve" })
      collection_id = response["id"]
    end

    @collection_id = collection_id
  end

  def reset_document
    TheDestroyor.new(@document).delete_embeddings

    @document.reset!
  end
end
