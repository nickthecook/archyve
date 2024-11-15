class Mediator
  class IngestError < StandardError; end
  class DocumentHasNoFile < IngestError; end
  class CannotIngestDocument < IngestError; end

  attr_reader :document

  def self.ingest(document)
    Mediator.new(document).execute
  end

  def initialize(document)
    @document = document
  end

  def execute
    case next_step
    when :fetch
      FetchWebDocumentJob.perform_async(document.id)
    when :chunk
      ChunkDocumentJob.perform_async(document.id)
    when :convert
      ConvertDocumentJob.perform_async(document.id)
    else
      raise CannotIngestDocument,
        "Cannot ingest document: #{document.filename || 'nil'}, #{document.content_type || 'unknown'}"
    end
  end

  private

  def next_step
    if document.filename.nil?
      if document.web?
        :fetch
      end
    elsif document.file.attached?
      if Parsers.can_chunk?(document)
        :chunk
      elsif Converters.can_convert?(document)
        :convert
      end
    end
  end
end
