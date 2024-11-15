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

    def self.can_parse?(filename, content_type)
      content_type&.end_with?("/html") || filename.match?(/\.?html*\z/)
    end

    private

    def text_type
      Chunkers::InputType::HTML
    end
  end
end
