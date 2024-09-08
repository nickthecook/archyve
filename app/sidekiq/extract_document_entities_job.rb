class ExtractDocumentEntitiesJob
  include Sidekiq::Job

  sidekiq_options retry: Rails.configuration.sidekiq_retries

  def perform(document_id)
    document = Document.find(document_id)
    document.update!(stop_jobs: false)

    document.extracting!
    document.update!(process_step: 0, process_steps: document.chunks.count)

    document.chunks.each do |chunk|
      ExtractChunkEntitiesJob.perform_async(chunk.id)
    end
  end
end
