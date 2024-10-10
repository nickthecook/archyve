module Parsers
  class Jpg < Base
    def initialize(document)
      super(document)
      @text = Base64.encode64(@document.contents)
    end

    private

    def text_type
      Chunkers::InputType::IMAGE_JPG
    end

    def chonker
      Chunkers.chunker_for(document.chunking_profile, text_type)
    end
  end
end
