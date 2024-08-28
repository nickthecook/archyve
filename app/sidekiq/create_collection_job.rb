class CreateCollectionJob
  include Sidekiq::Job

  sidekiq_options retry: 3

  def perform(collection_id)
    collection = Collection.find(collection_id)

    CreateCollection.new(collection).execute
  end
end
