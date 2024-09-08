class ChunkDocumentJob
  include Sidekiq::Job

  sidekiq_retries_exhausted do |job, _exception|
    document = Document.find(job['args'].first)

    document.update!(state: :errored)
  end

  def perform(document_id)
    document = Document.find(document_id)

    ChunkDocument.new(document).execute
  end
end
