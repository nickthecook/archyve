module Ingestion
  # Turns a Docling::Result into right-sized, structure-aware chunks.
  #
  # Docling gives us a flat, ordered list of text *elements* (paragraphs, list
  # items, captions, headers) — not "everything under a heading". So we walk
  # them tracking a heading stack, tag each body element (a Block) with its
  # heading path, then greedily pack consecutive blocks up to a target size (a
  # chunk per paragraph would retrieve badly and explode the row count). A single
  # block bigger than a chunk gets split with overlap. Each chunk's content is
  # prefixed with a heading breadcrumb — context for the embedding model and a
  # ready-made display header.
  class Chunker
    TARGET_CHARS = 1000  # fill a chunk up to here before starting a new one
    MAX_CHARS = 1500     # a single block longer than this gets split
    OVERLAP_CHARS = 150  # overlap between pieces of a split block

    Chunk = Data.define(:content, :structure)

    # A body element tagged with the heading path in effect where it appears.
    Block = Data.define(:heading_path, :text, :page)

    def initialize(target_chars: TARGET_CHARS, max_chars: MAX_CHARS, overlap_chars: OVERLAP_CHARS)
      @target_chars = target_chars
      @max_chars = max_chars
      @overlap_chars = overlap_chars
    end

    # => Array<Chunk>
    def chunk(result)
      pack(blocks_from(result.items))
    end

    private

    # Flatten items into body blocks, resolving each one's heading path from the
    # running heading stack. Heading items only update the stack; their text
    # rides along in the breadcrumb rather than becoming a block.
    def blocks_from(items)
      stack = [] # index = heading level, value = heading text
      items.filter_map do |item|
        if item.heading?
          stack = stack.first(item.level)
          stack[item.level] = item.text
          next
        end
        Block.new(heading_path: stack.compact, text: item.text, page: item.page)
      end
    end

    def pack(blocks)
      chunks = []
      buffer = []

      blocks.each do |block|
        if block.text.length > @max_chars
          chunks << build_chunk(buffer) unless buffer.empty?
          buffer = []
          split_text(block.text).each { |piece| chunks << build_chunk([block.with(text: piece)]) }
          next
        end

        if buffer.any? && buffer.sum { |b| b.text.length } + block.text.length > @target_chars
          chunks << build_chunk(buffer)
          buffer = []
        end
        buffer << block
      end

      chunks << build_chunk(buffer) unless buffer.empty?
      chunks
    end

    # Build one chunk from a run of blocks: print each distinct section's
    # breadcrumb once (consecutive blocks sharing a heading path), then its text.
    def build_chunk(blocks)
      sections = blocks.slice_when { |a, b| a.heading_path != b.heading_path }
      content = sections.map { |group| render_section(group) }.join("\n\n")
      Chunk.new(content: content, structure: structure_for(blocks))
    end

    def render_section(blocks)
      breadcrumb = blocks.first.heading_path.join(" > ")
      body = blocks.map(&:text).join("\n\n")
      breadcrumb.empty? ? body : "#{breadcrumb}\n\n#{body}"
    end

    def structure_for(blocks)
      paths = blocks.map(&:heading_path).uniq
      {
        heading_path: common_prefix(paths),
        headings: paths,
        pages: blocks.filter_map(&:page).uniq.sort
      }.compact_blank
    end

    def common_prefix(paths)
      return paths.first || [] if paths.size <= 1

      paths.reduce do |acc, path|
        acc.each_with_index.take_while { |seg, i| seg == path[i] }.map(&:first)
      end
    end

    # Char-window split at word boundaries with overlap, for a lone block bigger
    # than MAX_CHARS (an unbroken wall-of-text paragraph).
    def split_text(text)
      return [text] if text.length <= @max_chars

      pieces = []
      start = 0
      while start < text.length
        stop = [start + @target_chars, text.length].min
        stop = word_boundary(text, start, stop) if stop < text.length
        pieces << text[start...stop].strip
        break if stop >= text.length

        start = [stop - @overlap_chars, start + 1].max
      end
      pieces.reject(&:empty?)
    end

    def word_boundary(text, start, stop)
      space = text.rindex(/\s/, stop)
      space && space > start ? space : stop
    end
  end
end
