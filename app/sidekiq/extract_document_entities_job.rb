class ExtractDocumentEntitiesJob
  include Sidekiq::Job

  sidekiq_options retry: Rails.configuration.sidekiq_retries

  def perform(document_id)
    document = Document.find(document_id)

    document.extracting!
    Graph::ExtractDocumentEntities.new(document).execute
    if document.stop_jobs
      document.update!(stop_jobs: false)
      return
    end

    document.extracted!

    SummarizeCollectionJob.perform_async(document.collection.id)
    CleanCollectionEntitiesJob.perform_async(document.collection.id)
  end
end
