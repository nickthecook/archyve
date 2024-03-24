class TheIngestor
  def initialize(document)
    @document = document
  end

  def ingestorize
    chonker.chunks.each do |chunk|
      embedding = embedder.embed(chunk)
      chromadb.add_documents(collection_id, [chunk], [embedding])
    end
  end

  private

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

  def collection_id
    @collection_id ||= begin
      collections = chromadb.collections

      collection = collections.find { |c| c["name"] == @document.collection.slug }
      return collection["id"] if collection

      response = chromadb.create_collection(@document.collection.slug, { creator: "archyve" })

      response["id"]
    end
  end
end
