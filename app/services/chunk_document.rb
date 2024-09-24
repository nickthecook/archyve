class ChunkDocument
  def initialize(document)
    @document = document
  end

  def execute
    reset_document unless @document.created?

    @document.chunking!

    parser.chunks.each do |chunk_record|
      chunk = Chunk.create!(document: @document, content: chunk_record.content)

      if contextualize_chunks && model_server_can_contextualize
        ContextualizeChunkJob.perform_async(chunk.id)
      else
        EmbedChunkJob.perform_async(chunk.id)
      end
    end

    @document.chunked!
  end

  private

  def reset_document
    Rails.logger.warn("RESETTING DOCUMENT #{@document.id}: is in state #{@document.state}...")

    destroyor = TheDestroyor.new(@document)
    destroyor.delete_embeddings
    destroyor.delete_chunks
    destroyor.delete_graph_entities

    @document.reset!
  end

  def parser
    @parser ||= Parsers.parser_for(@document.filename).new(@document)
  end

  def chunks
    @chunks ||= parser.chunks
  end

  def contextualize_chunks
    Setting.get("contextualize_chunks", default: false)
  end

  def model_server_can_contextualize
    @document.collection.embedding_model.model_server.nil? || ModelServer.active_server&.provider == "ollama"
  end
end
