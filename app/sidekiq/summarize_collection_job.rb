class SummarizeCollectionJob
  include Sidekiq::Job

  sidekiq_options retry: 3

  def perform(collection_id)
    collection = Collection.find(collection_id)

    Graph::SummarizeCollectionEntities.new(collection).execute

    GraphCollectionJob.perform_async(collection_id)
  rescue StandardError => e
    Rails.logger.error("\n#{e.class.name}: #{e.message}#{e.backtrace.join("\n")}")

    collection.update!(state: :errored)
  end
end
