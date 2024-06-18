module Parsers
  # Plain text chunker that uses recursive text splitter
  class Text
    include RecursiveTextChunker

    def initialize(document)
      @document = document
    end

    def text
      @text ||= @document.contents
    end
  end
end
