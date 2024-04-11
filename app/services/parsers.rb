module Parsers

  def self.parser_for(filename)
    return Parsers::Pdf if filename.downcase.end_with?(".pdf")

    raise StandardError, "Unsupported file extension: '#{filename.slice(/\.\w+$/)}'"
  end
end
