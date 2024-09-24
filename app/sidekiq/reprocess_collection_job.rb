class ReprocessCollectionJob
  include Sidekiq::Job

  sidekiq_options retry: Rails.configuration.sidekiq_retries
  sidekiq_retries_exhausted do |job, exception|
    collection = Collection.find(job['args'].first)

    collection.update!(state: :errored, error_message: exception.to_s)
  end

  def perform(collection_id)
    collection = Collection.find(collection_id)

    if collection.summarized?
      Graph::CleanCollectionEntityVectors.new(collection).execute
      Graph::CleanGraph.new(collection_id).execute
      Graph::ResetCollection.new(collection).execute
    else
      Rails.logger.info("Collection #{collection.id} is not fully summarized. Resuming...")
    end

    SummarizeCollectionJob.perform_async(collection_id)
  end
end
