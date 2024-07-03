class TheIngestor
  def initialize(document)
    @document = document
    @chunks = []
  end

  def ingest
    ensure_collection_exists
    @document.chunking!
    prepare_and_embed(chonker.each)
    @document.embedded!
    Rails.logger.info("Embedded chunks from #{@document.filename}.")
  rescue StandardError => e
    Rails.logger.error("Error ingesting document #{@document.id}\n#{exception_summary(e)}")
    @document.error!

    raise e
  end

  private

  def exception_summary(err)
    "#{err.class.name}: #{err.message}#{err.backtrace.join("\n")}"
  end

  def prepare_and_embed(chunk_records)
    @document.chunked!
    @document.embedding!
    chunk_records.each do |chunk_record|
      chunk = Chunk.create!(
        document: @document, content: chunk_record.content,
        embedding_content: chunk_record.embedding_content
      )
      embed(chunk)
    end
  end

  def embed(chunk)
    embedding = embedder.embed(chunk.embedding_content)
    ids = chromadb.add_documents(@collection_id, [chunk.content], [embedding])
    chunk.update!(vector_id: ids.first)
  end

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
    @embedder ||= Embedder.new(embedding_model, traceable: @document)
  end

  def embedding_model
    @document.collection.embedding_model
  end

  def chromadb
    @chromadb ||= Chromadb::Client.new(traceable: @document)
  end

  def collection_name
    @document.collection.slug
  end

  def initialize_collection
    # this causes chromadb to print a pretty big stack trace; use /collections instead
    collection_id = fetch_collection_id

    if collection_id.nil?
      response = chromadb.create_collection(collection_name, { creator: "archyve" })
      collection_id = response["id"]
    end

    @collection_id = collection_id
  end

  def reset_document
    TheDestroyor.new(@document).delete_embeddings

    @collection_id = fetch_collection_id
    @document.reset!
  end

  def fetch_collection_id
    chromadb.collection_id(collection_name)
  end
end
