class ChunkDocumentJob
  include Sidekiq::Job

  sidekiq_options retry: 1
  sidekiq_retries_exhausted do |job, exception|
    document = Document.find(job['args'].first)

    document.update!(state: :errored, error_message: exception.to_s)
  end

  def perform(document_id)
    document = Document.find(document_id)

    ChunkDocument.new(document).execute
  end
end
