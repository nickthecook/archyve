class ChunkDocument
  def initialize(document)
    @document = document
  end

  def execute
    reset_document unless @document.created?

    @document.chunking!

    parser.chunks.each do |chunk_record|
      chunk = Chunk.create!(document: @document, content: chunk_record.content)

      EmbedChunkJob.perform_async(chunk.id)
    end

    @document.update(title: parser.get_title)

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
end
