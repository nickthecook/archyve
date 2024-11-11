module Mediator
  class DocumentHasNoFile < StandardError; end

  def self.ingest(document)
    if document.filename.nil?
      # Document has no file, so kick off fetching if it's a link
      raise DocumentHasNoFile, "No file exists, file name is nil" unless document.web?

      FetchWebDocumentJob.perform_async(document.id)
    else
      # Document has a file, so kick off chunking
      ChunkDocumentJob.perform_async(document.id)
    end
  end
end
