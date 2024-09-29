require 'baran'

module Chunkers
  # Chunker splits text by recursively look at characters.
  # Recursively tries to split by different characters to find one that works.
  class RecursiveTextChunker
    # Separators suitable for chunking html (headings and paragraphs)
    HTML_SEPARATORS = %w[h1 h2 h3 h4 h5 h6 p]

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

    def initialize(chunking_profile, text_type)
      @chunking_profile = chunking_profile
      @text_type = text_type
    end

    def chunk(text)
      raw_chunks_from(text).map do |c|
        ChunkRecord.new(content: c[:text])
      end
    end

    private

    # Internal chunker returns array of chunks
    def raw_chunks_from(text)
      chunk_size = chunking_profile.size
      chunk_overlap = chunking_profile.overlap

      if @text_type == Chunkers::InputType::HTML
        Nokogiri::HTML(text)
          .css(HTML_SEPARATORS.join(",")).map(&:inner_text).map { |t| { text: t } }
      else
        splitter = Baran::RecursiveCharacterTextSplitter.new(
          chunk_size:,
          chunk_overlap:,
          separators:
        )
        splitter.chunks(text)
      end
    end

    def separators
      case @text_type
      when InputType::COMMON_MARK
        COMMONMARK_SEPARATORS
      when InputType::HTML
        HTML_SEPARATORS
      else
        PLAINTEXT_SEPARATORS
      end
    end
  end
end
