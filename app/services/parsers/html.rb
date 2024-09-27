module Parsers
  class Html < Text
    private

    def text_type
      Chunkers::InputType::HTML
    end
  end
end
