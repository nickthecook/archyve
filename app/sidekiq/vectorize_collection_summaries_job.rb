class VectorizeCollectionSummariesJob
  include Sidekiq::Job

  sidekiq_options retries: 3

  def perform(collection_id)
    collection = Collection.find(collection_id)

    VectorizeCollectionSummaries.new(collection).execute
  end
end
