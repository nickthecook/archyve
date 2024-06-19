module Parsers
  # A chunk record has the content and its key, where the `key` is used to generate the
  # embedding. If a chunk record is created without a key, the content is used as the key.
  class ChunkRecord
    attr_reader :content

    def initialize(content:, key: nil)
      raise StandardError, "Content required" if content.nil? || content.blank?

      @content = content
      @key = key
    end

    def key
      # Use content as the key for embedding if no separate key specified
      @key || content
    end
  end
end
