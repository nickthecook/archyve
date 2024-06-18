require 'baran'

module Parsers
  # Chunker splits text by recursively look at characters.
  # Recursively tries to split by different characters to find one that works.
  module RecursiveTextChunker
    def chunk_by_bytes
      chunk_size = chunking_profile.size
      chunk_overlap = chunking_profile.overlap
      splitter = Baran::RecursiveCharacterTextSplitter.new chunk_size:,
                                                           chunk_overlap:,
                                                           separators: chunking_separators

      splitter.chunks(text).map do |c|
        c[:text]
      end
    end

    # The chunking profile used by the parser, based on the document it is parsing
    def chunking_profile
      @document.chunking_profile
    end

    # Override this to return alternate separators; the default is good for plain text.
    def chunking_separators
      [
        "\n\n", # new line
        "\n", # new line
        " ", # space
        "", # empty
      ]
    end
  end
end
