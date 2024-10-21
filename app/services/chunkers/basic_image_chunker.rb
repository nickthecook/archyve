module Chunkers
  class BasicImageChunker
    attr_reader :chunking_profile

    def initialize(chunking_profile, text_type)
      @chunking_profile = chunking_profile
      @text_type = text_type
    end

    # Return Enumerable with single chunk
    def chunk(parser)
      [ChunkRecord.new(
        content: parser.text,
        embedding_content: 'Unknown image...')]
    end
  end
end
