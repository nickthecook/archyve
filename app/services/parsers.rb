module Parsers
  def self.parser_for(filename)
    return Parsers::Pdf if filename.end_with?(".pdf")
  end
end
