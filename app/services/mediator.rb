module Mediator
  class DocumentHasNoFile < StandardError; end
  class DocumentNotChunkable < StandardError; end

  # Returns true if the document's content type is chunkable
  def self.chunkable?(document)
    document.file.attached? && Parsers.textual?(document.content_type)
  end

  # Return true if document needs to be fetched?
  def self.fetchable?(document)
    document.filename.nil?
  end

  def self.ingest(document)
    if fetchable?(document)
      # Document has no file, so kick off fetching if it's a link
      raise DocumentHasNoFile, "No file exists, file name is nil" unless document.web?

      FetchWebDocumentJob.perform_async(document.id)
    elsif chunkable?(document)
      # Document has a file, so kick off chunking
      ChunkDocumentJob.perform_async(document.id)
    else
      raise DocumentNotChunkable, "Document: #{document.filename}, #{document.content_type}"
    end
  end
end
