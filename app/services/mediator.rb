module Mediator
  class IngestError < StandardError; end
  class DocumentHasNoFile < IngestError; end
  class DocumentNotChunkable < IngestError; end
  class ConversionUnimplemented < IngestError; end

  def self.ingest(document)
    case next_step(document)
    when :fetch
      # Document has no file, so kick off fetching if it's a link
      raise DocumentHasNoFile, "No file exists, file name is nil" unless document.web?

      FetchWebDocumentJob.perform_async(document.id)
    when :chunk
      # Document has a file, so kick off chunking
      ChunkDocumentJob.perform_async(document.id)
    when :convert
      # TODO: implement conversion to a chunkable format
      raise ConversionUnimplemented, "Cannot convert: #{document.filename}, #{document.content_type}"
    else
      raise DocumentNotChunkable, "Cannot ingest document: #{document.filename}, #{document.content_type}"
    end
  end

  def self.next_step(document)
    if document.filename.nil?
      :fetch
    elsif document.file.attached?
      if Parsers.textual?(document.content_type)
        :chunk
      elsif need_conversion?(document)
        :convert
      end
    end
  end

  def self.need_conversion?(document)
    document.image? || document.audio? || document.video?
  end
end
