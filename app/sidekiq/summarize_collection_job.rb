class SummarizeCollectionJob
  include Sidekiq::Job

  sidekiq_options retry: Rails.configuration.sidekiq_retries
  sidekiq_retries_exhausted do |job, exception|
    collection = Collection.find(job['args'].first)

    collection.update!(state: :errored, error_message: exception.to_s)
  end

  def perform(collection_id)
    collection = Collection.find(collection_id)

    Graph::SummarizeCollectionEntities.new(collection).execute
    if collection.reload.stop_jobs
      collection.update!(stop_jobs: false)
      return
    end

    VectorizeCollectionSummariesJob.perform_async(collection.id)
  end
end
