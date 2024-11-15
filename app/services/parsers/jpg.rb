module Parsers
  class Jpg < Image
    def initialize(document)
      super(document)
      @text = Base64.encode64(@document.contents) # or strict_encode64?
    end

    def self.can_parse?(filename, content_type)
      content_type&.end_with?("/jpeg") || filename.end_with?(".jpg")
    end

    private

    def text_type
      Chunkers::InputType::JPG
    end
  end
end
