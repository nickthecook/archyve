module Parsers
  class Image < Base
    private

    def text_type
      Chunkers::InputType::JPG
    end

    def chonker
      Chunkers.chunker_for(document.chunking_profile, text_type)
    end
  end
end
