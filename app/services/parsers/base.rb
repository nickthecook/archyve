#require "strscan"

module Parsers
  class Base
    attr_reader :document

    def initialize(document)
      @document = document
    end

    # Enumerable chunk records
    def chunks
      chonker.chunk(self)
    end

    # Override to return the document's text if any additional processing is needed
    def text
      @text ||= @document.contents
    end

    # Overriede to set approriate title
    def title
      ''
    end

    def filename
      @document.filename
    end
  end

  private

  def text_type
    raise NotImplementedError
  end

  def chonker
    raise NotImplementedError
  end
end
