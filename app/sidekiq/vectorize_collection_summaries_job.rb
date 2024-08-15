class VectorizeCollectionSummariesJob
  include Sidekiq::Job

  sidekiq_options retries: 3

  def perform(collection_id)
    collection = Collection.find(collection_id)

    Graph::VectorizeCollectionSummaries.new(collection).execute

    GraphCollectionJob.perform_async(collection_id)
  end
end
