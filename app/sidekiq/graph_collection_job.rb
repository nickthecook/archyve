class GraphCollectionJob
  include Sidekiq::Job

  sidekiq_options retry: 3

  def perform(collection_id)
    collection = Collection.find(collection_id)

    Graph::GraphCollectionEntities.new(collection).execute
  rescue StandardError => e
    Rails.logger.error("\n#{e.class.name}: #{e.message}#{e.backtrace.join("\n")}")

    collection.update!(state: :errored)
  end
end
