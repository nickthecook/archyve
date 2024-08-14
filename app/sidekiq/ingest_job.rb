class IngestJob
  include Sidekiq::Job

  sidekiq_options retry: false

  def perform(*args)
    @document = Document.find(args.first)

    TheIngestor.new(@document).execute

    ExtractDocumentEntitiesJob.perform_async(@document.id) if @document.collection.graph_enabled?
  end
end
