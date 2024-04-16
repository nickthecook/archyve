module Parsers
  class Text
    include BasicTextChunker

    def initialize(document)
      @document = document
    end

    def text
      @text ||= @document.contents
    end
  end
end
