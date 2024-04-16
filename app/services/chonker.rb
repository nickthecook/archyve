class Chonker
  # implement basic text chunker until all parsers will be self-chunking
  include Parsers::BasicTextChunker

  class UnknownChunkingMethod < StandardError; end

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

    chunker = (@parser.is_a?(Parsers::SelfChunker) && @parser) || self
    chunker.send(CHUNKING_METHODS[@profile.method], @profile)
  end

  private

  def text
    @text ||= @parser.text.dup
  end
end
