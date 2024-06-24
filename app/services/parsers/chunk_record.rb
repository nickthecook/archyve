module Parsers
  # A chunk record has the content and its "embedding content" which is used to generate the
  # embedding. If a chunk record is created without a separately specific `embedding_content`,
  # the `content`` is used instead.
  class ChunkRecord
    attr_reader :content

    def initialize(content:, embedding_content: nil)
      @content = content
      @embedding_content = embedding_content
    end

    def embedding_content
      # Use content as the key for embedding if no separate key specified
      @embedding_content || content
    end
  end
end
