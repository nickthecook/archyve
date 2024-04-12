module Parsers
  class Text
    def initialize(document)
      @document = document
    end

    def text
      @text ||= @document.contents
    end

  end
end
