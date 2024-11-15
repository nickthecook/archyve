module Converters
  class ConversionError < StandardError; end
  class UnsupportedDocumentFormat < ConversionError; end
  class UnimplementedConverter < ConversionError; end

  module Status
    READY = 0
    CONVERTING = 1
    DONE = 2
    ERROR = 3
  end

  ENABLED = [PdfToText].freeze

  def self.can_convert?(document)
    ENABLED.any? { |c| c.can_convert?(document) }
  end

  def self.find(document)
    converters = ENABLED.select { |c| c.can_convert?(document) }
    return converters.first.new(document) unless converters.empty?

    raise UnsupportedDocumentFormat, "No converter available: #{document.filename}, #{document.content_type}"
  end
end
