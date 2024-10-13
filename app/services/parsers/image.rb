module Parsers
  class Image < Base
    private

    def chonker
      Chunkers.chunker_for(document.chunking_profile, text_type)
    end
  end
end
