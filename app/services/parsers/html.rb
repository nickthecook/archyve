module Parsers
  class Html < Text
    def get_title
      Nokogiri::HTML(@document.text).css('title').text
    end

    private

    def text_type
      Chunkers::InputType::HTML
    end
  end
end
