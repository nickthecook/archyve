class CleanCollectionEntitiesJob
  include Sidekiq::Job

  def perform(collection_id)
    collection = Collection.find(collection_id)

    Graph::CleanCollectionEntities.new(collection).execute
  end
end
