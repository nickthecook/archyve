module Parsers
  class UnsupportedFileFormat < StandardError; end

  # Returns true if the `content_type` refers to content that can be parsed into
  # text for chunking
  def self.textual?(content_type)
    content_type.start_with?("text/") ||
      ["application/pdf", "application/html"].include?(content_type) ||
      ["officedocument.word"].any? { |t| content_type.include?(t) }
  end

  def self.parser_for(filename)
    name_locase = filename.downcase

    return Pdf if name_locase.end_with?(".pdf")
    return Docx if name_locase.end_with?(".docx")
    return CommonMark if name_locase.end_with?(".md")
    return Text if name_locase.end_with?(".txt")
    return HtmlViaMarkdown if name_locase.match?(/\.?html*\z/)
    return Jpg if name_locase.end_with?(".jpg")

    raise UnsupportedFileFormat, "Unsupported file extension: '#{filename.slice(/\.\w+$/)}'"
  end
end
