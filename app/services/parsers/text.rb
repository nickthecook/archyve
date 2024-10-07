module Parsers
  # Plain text parser
  class Text
    attr_reader :document

    def initialize(document)
      @document = document
    end

    # Enumerable chunk records
    def chunks
      chonker.chunk(self)
    end

    # Override to return the document's text if any additional processing is needed
    def text
      @text ||= @document.contents
    end

    # Overriede to set approriate title
    def title
      ''
    end

    private

    def text_type
      Chunkers::InputType::PLAIN_TEXT
    end

    def chonker
      Chunkers.chunker_for(document.chunking_profile, text_type)
    end
  end
end
