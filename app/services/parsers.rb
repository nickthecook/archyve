module Parsers

  # A parser can include this to indicate it can do its own chunking, implementing
  # `#chunk_METHOD(profile) for supported chunking methods, with at least `bytes` method. `
  module SelfChunker; end

  def self.parser_for(filename)
    name_locase = filename.downcase
    return Parsers::Pdf if name_locase.end_with?(".pdf")
    return Parsers::Text if name_locase.end_with?(".txt", ".html", ".md")

    raise StandardError, "Unsupported file extension: '#{filename.slice(/\.\w+$/)}'"
  end
end
