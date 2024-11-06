module Chunkers
  class BasicImageChunker
    attr_reader :chunking_profile

    def initialize(chunking_profile, text_type)
      @chunking_profile = chunking_profile
      @text_type = text_type
    end

    # Return Enumerable with single chunk
    def chunk(parser) # rubocop:disable Lint/UnusedMethodArgument
      [ChunkRecord.new(
        content: '', # TODO: parser.text
        embedding_content: '')] # or here?
    end
  end
end
