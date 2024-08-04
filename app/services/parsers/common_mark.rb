module Parsers
  # Markdown text parser
  class CommonMark < Text
    private

    def text_type
      Chunkers::InputType::COMMON_MARK
    end
  end
end
