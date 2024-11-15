module Parsers
  # Plain text parser

  class Text < Base
    def self.can_parse?(filename, content_type)
      content_type&.end_with?("text/plain") || filename.end_with?(".txt")
    end

    private

    def text_type
      Chunkers::InputType::PLAIN_TEXT
    end

    def chonker
      Chunkers.chunker_for(document.chunking_profile, text_type)
    end
  end
end
