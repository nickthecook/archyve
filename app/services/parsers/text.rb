module Parsers
  # Plain text parser
  class Text
    attr_reader :document

    def initialize(document)
      @document = document
    end

    # Enumerable chunk records
    def chunks
      supported_chunker.chunk(text)
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

    def chunking_method
      chunking_profile.method
    end

    def chunking_profile
      document.chunking_profile
    end

    def supported_chunker
      @chunker ||= case chunking_method
      when "basic"
        Chunkers::BasicCharacterChunker.new(chunking_profile)
      when "recursive_split"
        Chunkers::RecursiveTextChunker.new(
          chunking_profile,
          chunking_separators: recursive_chunking_separators)
      else
        raise UnsupportedChunkingMethod,
          "#{self.class} does not support chunking method '#{chunking_method}"
      end
    end
  end
end
