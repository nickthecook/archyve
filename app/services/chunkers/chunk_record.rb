module Chunkers
  # A chunk record has the content and its "embedding content" which is used to generate the
  # embedding. If a chunk record is created without a separately specific `embedding_content`,
  # the `content`` is used instead.
  class ChunkRecord
    attr_reader :excerpt, :surrounding_content, :headings, :location_summary

    def initialize(excerpt:, surrounding_content: nil, headings: nil, location_summary: nil)
      @excerpt = excerpt
      @surrounding_content = surrounding_content || excerpt
      @headings = headings
      @location_summary = location_summary
    end

    def embedding_content
      # Assemble the embedding content used to generate the
      # vector embeddings
      text = ""
      if headings
        text << headings << "\n\n"
      end
      if location_summary
        text << location_summary << "\n\n"
      end
      # Use document excerpt if no surrounding content provided (compatibility)
      text << (surrounding_content || excerpt)
    end
  end
end
