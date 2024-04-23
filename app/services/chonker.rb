class Chonker
  class UnknownChunkingMethod < StandardError; end
  class UnsupportedChunkingMethod < StandardError; end

  CHUNKING_METHODS = {
    "bytes" => :chunk_by_bytes,
    "sentences" => :chunk_by_sentences,
    "paragraphs" => :chunk_by_paragraphs,
    "pages" => :chunk_by_pages,
  }.freeze

  def initialize(parser)
    @parser = parser
  end

  # Yield each chunk
  def each(&block)
    if block_given?
      chunks.each(&block)
    else
      chunks.each
    end
  end

  private

  def chunks
    raise UnknownChunkingMethod, "Unknown chunking method '#{chunking_method}'" unless CHUNKING_METHODS[chunking_method]

    begin
      @parser.send(CHUNKING_METHODS[chunking_method])
    rescue NoMethodError
      raise UnsupportedChunkingMethod,
              "Parser (#{@parser.class.name}) doesn't support chunking method '#{chunking_method}'"
    end
  end

  def chunking_method
    @parser.chunking_profile.method
  end
end
