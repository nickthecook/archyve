class Chonker
  class UnknownChunkingMethod < StandardError; end

  CHUNKING_METHODS = {
    bytes: :chunk_by_bytes,
    sentences: :chunk_by_sentences,
    paragraphs: :chunk_by_paragraphs,
    pages: :chunk_by_pages,
  }
  DEFAULTS = {
    bytes: 120,
    overlap: 20
  }

  def initialize(parser, method, options = {})
    @parser = parser
    @method = method
    @options = DEFAULTS.merge(options)
  end

  def chunks
    raise UnknownChunkingMethod, @method unless CHUNKING_METHODS[@method]

    send(CHUNKING_METHODS[@method])
  end

  private

  def chunk_by_bytes
    chunk_size = @options[:bytes]

    chunks = text.gsub(/  +/, "  ").gsub(/\n\n+/, "\n\n").scan(/.{0,#{chunk_size}}\b /m)

    overlap_chunks(chunks)
  end

  def overlap_chunks(chunks)
    chunk_overlap = @options[:overlap]
    chunk_size = @options[:bytes]
    overlapped_chunks = []

    chunks.each_with_index do |chunk, idx|
      prev_chunk = chunks[idx-1] if idx > 0
      next_chunk = chunks[idx+1] if idx < (chunks.length - 1)

      puts "CHUNK #{chunk}"
      # TODO: this is horribly inefficient - stop copying so much string data around
      if prev_chunk
        ending_of_prev_chunk = prev_chunk.match(/\b(.{1,20})\Z/m)
        chunk = "#{ending_of_prev_chunk[1] if ending_of_prev_chunk}#{chunk}"
      end

      if next_chunk
        beginning_of_next_chunk = next_chunk.match(/^(.{1,20})\b/)
        chunk = "#{chunk}#{beginning_of_next_chunk[1] if beginning_of_next_chunk}"
      end

      overlapped_chunks << chunk
    end

    overlapped_chunks
  end

  def text
    @text ||= @parser.text.dup
  end
end
