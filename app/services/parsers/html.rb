module Parsers
  class Html < Text
    attr_reader :doc

    def initialize(document)
      super(document)
      @doc = Nokogiri::HTML(@document.contents)
    end

    def title
      @doc.css('title').text
    end

    private

    def text_type
      Chunkers::InputType::HTML
    end
  end
end
