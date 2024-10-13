module Parsers
  class Jpg < Image
    def initialize(document)
      super(document)
      @text = Base64.encode64(@document.contents)
    end

    private

    def text_type
      Chunkers::InputType::JPG
    end
  end
end
