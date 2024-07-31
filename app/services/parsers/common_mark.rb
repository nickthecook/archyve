module Parsers
  # Markdown text parser
  class CommonMark < Text
    def recursive_chunking_separators
      Chunkers::RecursiveTextChunker::COMMONMARK_SEPARATORS
    end
  end
end
