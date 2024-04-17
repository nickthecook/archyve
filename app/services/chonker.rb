class Chonker
  class UnknownChunkingMethod < StandardError; end
  class UnsupportedChunkingMethod < StandardError; end

  CHUNKING_METHODS = {
    "bytes" => :chunk_by_bytes,
    "sentences" => :chunk_by_sentences,
    "paragraphs" => :chunk_by_paragraphs,
    "pages" => :chunk_by_pages,
  }.freeze

  def initialize(parser, profile)
    @parser = parser
    @profile = profile
  end

  def chunks
    raise UnknownChunkingMethod, "Unknown chunking method '#{@profile.method}'" unless CHUNKING_METHODS[@profile.method]

    begin
      @parser.send(CHUNKING_METHODS[@profile.method], @profile)
    rescue NoMethodError
      raise UnsupportedChunkingMethod,
              "Parser (#{@parser.class.name}) doesn't support chunking method '#{@profile.method}'"
    end
  end
end
