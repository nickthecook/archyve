require 'baran'

module Chunkers
  # Chunker splits text by recursively look at characters.
  # Recursively tries to split by different characters to find one that works.
  class RecursiveTextChunker
    # Recursive text splitting separators suitable for chunking CommonMark text
    COMMONMARK_SEPARATORS = [
      # markdown-specific separators
      "\n# ", # h1
      "\n## ", # h2
      "\n### ", # h3
      "\n#### ", # h4
      "\n##### ", # h5
      "\n###### ", # h6
      "```\n\n", # code block
      "\n\n***\n\n", # horizontal rule
      "\n\n---\n\n", # horizontal rule
      "\n\n___\n\n", # horizontal rule
      "\n\n", # new line

      # html table content-related separators
      "\n<table",
      "<tr",  # may have attributes
      "<td>",
      "<ul>", # html lists (usually within tables)
      "<ol>",
      "<li>",

      # plain text
      "\n", # new line
      " ", # space
      "", # empty
    ]

    # Recursive text splitting separators suitable for chunking plain text
    PLAINTEXT_SEPARATORS = [
      "\n\n", # new line
      "\n", # new line
      " ", # space
      "", # empty
    ]

    attr_reader :chunking_profile, :chunking_separators

    def initialize(chunking_profile)
      @chunking_profile = chunking_profile
    end

    def chunk(text, text_type = InputType::PLAIN_TEXT)
      raw_chunks_from(text, separators_for(text_type)).map do |c|
        ChunkRecord.new(content: c[:text])
      end
    end

    private

    # Internal chunker returns array of chunks
    def raw_chunks_from(text, separators)
      chunk_size = chunking_profile.size
      chunk_overlap = chunking_profile.overlap
      splitter = Baran::RecursiveCharacterTextSplitter.new(
        chunk_size:,
        chunk_overlap:,
        separators:
      )

      splitter.chunks(text)
    end

    def separators_for(text_type)
      case text_type
      when InputType::COMMON_MARK
        COMMONMARK_SEPARATORS
      else
        PLAINTEXT_SEPARATORS
      end
    end
  end
end
