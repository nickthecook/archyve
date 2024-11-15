module Parsers
  class UnsupportedFileFormat < StandardError; end

  ENABLED = [Docx, CommonMark, Text, HtmlViaMarkdown].freeze

  # Returns true if the `content_type` refers to content that can be parsed into
  # text for chunking
  def self.can_chunk?(document)
    name_locase = document.filename.downcase
    content_type = document.content_type

    ENABLED.any? { |p| p.can_parse?(name_locase, content_type) }
  end

  def self.parser_for(filename, content_type = nil)
    name_locase = filename.downcase

    parsers = ENABLED.select { |p| p.can_parse?(name_locase, content_type) }
    return parsers.first unless parsers.empty?

    raise UnsupportedFileFormat, "Unsupported extension '#{filename.slice(/\.\w+$/)}', #{content_type}"
  end
end
