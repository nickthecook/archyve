module Parsers
  class UnsupportedFileFormat < StandardError; end

  ENABLED = [Pdf, Docx, CommonMark, Text, HtmlViaMarkdown, Jpg].freeze

  # Returns true if the `content_type` refers to content that can be parsed into
  # text for chunking
  def self.textual?(content_type)
    content_type.start_with?("text/") ||
      ["application/pdf", "application/html"].include?(content_type) ||
      ["officedocument.word"].any? { |t| content_type.include?(t) }
  end

  def self.parser_for(filename, content_type = nil)
    name_locase = filename.downcase

    parsers = ENABLED.select { |p| p.can_parse?(name_locase, content_type) }
    return parsers.first unless parsers.empty?

    raise UnsupportedFileFormat, "Unsupported file extension: '#{filename.slice(/\.\w+$/)}'"
  end
end
