class ChunkDocument
  def initialize(document)
    @document = document
  end

  def execute
    reset_document unless @document.created?

    @document.chunking!

    parser.chunks.each do |chunk_record|
      chunk = build_chunk(chunk_record)
      EmbedChunkJob.perform_async(chunk.id)
    end

    @document.update(title: parser.title)

    @document.chunked!
  end

  private

  def build_chunk(chunk_record)
    if chunk_record.embedding_content == chunk_record.content
      Chunk.create!(
        document: @document,
        content: chunk_record.content)
    else
      Chunk.create!(
        document: @document,
        content: chunk_record.content,
        embedding_content: chunk_record.embedding_content)
    end
  end

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
