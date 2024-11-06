module Parsers
  class UnsupportedFileFormat < StandardError; end

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
