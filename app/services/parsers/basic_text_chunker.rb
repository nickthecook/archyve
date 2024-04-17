module Parsers
  module BasicTextChunker
    def chunk_by_bytes(profile)
      chunk_size = profile.size

      chunks = text.gsub(/  +/, "  ").gsub(/\n\n+/, "\n\n").scan(/.{0,#{chunk_size}}\b /m)

      overlapped_chunks(chunks, profile)
    end

    private

    def overlapped_chunks(chunks, profile)
      chunk_overlap = profile.overlap
      overlapped_chunks = []

      chunks.each_with_index do |chunk, idx|
        prev_chunk = chunks[idx - 1] if idx.positive?
        next_chunk = chunks[idx + 1] if idx < (chunks.length - 1)

        # TODO: this is horribly inefficient - stop copying so much string data around
        if prev_chunk
          ending_of_prev_chunk = prev_chunk.match(/\b(.{1,#{chunk_overlap}})\Z/m)
          chunk = "#{ending_of_prev_chunk[1] if ending_of_prev_chunk}#{chunk}"
        end

        if next_chunk
          beginning_of_next_chunk = next_chunk.match(/^(.{1,#{chunk_overlap}})\b/)
          chunk = "#{chunk}#{beginning_of_next_chunk[1] if beginning_of_next_chunk}"
        end

        overlapped_chunks << chunk
      end

      overlapped_chunks
    end
  end
end
