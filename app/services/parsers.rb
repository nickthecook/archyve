module Parsers
  def self.parser_for(filename)
    name_locase = filename.downcase
    return Parsers::Pdf if name_locase.end_with?(".pdf")
    return Parsers::Docx if name_locase.end_with?(".docx")
    return Parsers::Text if name_locase.end_with?(".txt", ".html", ".md")

    raise StandardError, "Unsupported file extension: '#{filename.slice(/\.\w+$/)}'"
  end
end
