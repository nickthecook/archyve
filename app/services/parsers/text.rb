module Parsers
  # Plain text parser
  class Text
    attr_reader :document

    def initialize(document)
      @document = document
    end

    # Enumerable chunk records
    def chunks
      chunker.chunk(text, text_type:)
    end

    # Override to return more content-specific recursive chunking separators
    def recursive_chunking_separators
      Chunkers::RecursiveTextChunker::PLAINTEXT_SEPARATORS
    end

    # Override to return the document's text if any additional processing is needed
    def text
      @text ||= @document.contents
    end

    private

    def text_type
      Chunkers::InputType::PLAIN_TEXT
    end

    def chunker
      Chunkers.chunker_for(document.chunking_profile)
    end
  end
end
