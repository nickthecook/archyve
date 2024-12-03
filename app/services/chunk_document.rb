class ChunkDocument
  def initialize(document)
    @document = document
  end

  def execute
    reset_document unless @document.created?

    @document.chunking!
    create_chunks
    @document.update(title: parser.title)
    @document.chunked!
  end

  private

  def create_chunks
    parser.chunks.each do |chunk_record|
      chunk = Chunk.create!(
        document: @document,

        excerpt: chunk_record.excerpt,
        headings: chunk_record.headings,
        location_summary: chunk_record.location_summary,
        surrounding_content: chunk_record.surrounding_content,
        embedding_content: chunk_record.embedding_content)

      EmbedChunkJob.perform_async(chunk.id)
    end
  end

  def reset_document
    Rails.logger.warn("RESETTING DOCUMENT #{@document.id}: is in state #{@document.state}...")

    DocumentResetHelper.new(@document).execute
    @document.reset!
  end

  def parser
    @parser ||= Parsers.parser_for(@document.filename, @document.content_type).new(@document)
  end

  def chunks
    @chunks ||= parser.chunks
  end
end
