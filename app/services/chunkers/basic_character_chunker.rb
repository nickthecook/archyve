module Chunkers
  class BasicCharacterChunker
    attr_reader :chunking_profile

    def initialize(chunking_profile, text_type)
      @chunking_profile = chunking_profile
      @text_type = text_type
    end

    # Return Enumerable with chunks
    def chunk(text)
      chunk_size = chunking_profile.size

      raw_chunks = text.gsub(/  +/, "  ").gsub(/\n\n+/, "\n\n").scan(/.{0,#{chunk_size}}\b /m)

      if chunking_profile.overlap.zero?
        chunk_records(raw_chunks)
      else
        overlapped_chunk_records(raw_chunks)
      end
    end

    private

    def chunk_overlap
      chunking_profile.overlap
    end

    def overlapped_chunk_records(raw_chunks)
      overlapped_chunks = []

      raw_chunks.each_with_index do |chunk, idx|
        chunk = overlap_prev_chunk(chunk, raw_chunks[idx - 1]) if idx.positive?
        chunk = overlap_next_chunk(chunk, raw_chunks[idx + 1]) if idx < (raw_chunks.length - 1)

        overlapped_chunks << ChunkRecord.new(content: chunk)
      end

      overlapped_chunks
    end

    def overlap_next_chunk(chunk, next_chunk)
      return unless next_chunk

      # TODO: this is horribly inefficient - stop copying so much string data around
      beginning_of_next_chunk = next_chunk.match(/^(.{1,#{chunk_overlap}})\b/)
      "#{chunk}#{beginning_of_next_chunk[1] if beginning_of_next_chunk}"
    end

    def overlap_prev_chunk(chunk, prev_chunk)
      return unless prev_chunk

      # TODO: this is horribly inefficient - stop copying so much string data around
      ending_of_prev_chunk = prev_chunk.match(/\b(.{1,#{chunk_overlap}})\Z/m)
      "#{ending_of_prev_chunk[1] if ending_of_prev_chunk}#{chunk}"
    end

    def chunk_records(raw_chunks)
      raw_chunks.map { |chunk| ChunkRecord.new(content: chunk) }
    end
  end
end
