module Parsers
  class Jpg < Image
    def initialize(document)
      super(document)
      @text = Base64.encode64(@document.contents) # or strict_encode64?
    end

    private

    def text_type
      Chunkers::InputType::JPG
    end
  end
end
