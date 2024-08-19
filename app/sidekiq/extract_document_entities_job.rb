class ExtractDocumentEntitiesJob
  include Sidekiq::Job

  sidekiq_options retry: 3

  def perform(document_id)
    document = Document.find(document_id)

    document.extracting!
    Graph::ExtractDocumentEntities.new(document).execute
    document.extracted!

    SummarizeCollectionJob.perform_async(document.collection.id)
    CleanCollectionEntitiesJob.perform_async(document.collection.id)
  end
end
