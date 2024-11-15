module Parsers
  # Markdown text parser
  class CommonMark < Text
    def self.can_parse?(filename, content_type)
      content_type&.end_with?("/markdown") || filename.end_with?(".md")
    end

    private

    def text_type
      Chunkers::InputType::COMMON_MARK
    end
  end
end
