class GraphCollectionJob
  include Sidekiq::Job

  sidekiq_options retry: Rails.configuration.sidekiq_retries
  sidekiq_retries_exhausted do |job, exception|
    collection = Collection.find(job['args'].first)

    collection.update!(state: :errored, error_message: exception.to_s)
  end

  def perform(collection_id)
    collection = Collection.find(collection_id)

    Graph::GraphCollectionEntities.new(collection).execute
  end
end
