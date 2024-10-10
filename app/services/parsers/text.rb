module Parsers
  # Plain text parser

  class Text < Base
    private

    def text_type
      Chunkers::InputType::PLAIN_TEXT
    end

    def chonker
      Chunkers.chunker_for(document.chunking_profile, text_type)
    end
  end
end
