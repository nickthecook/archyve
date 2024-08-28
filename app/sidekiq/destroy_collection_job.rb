class DestroyCollectionJob
  include Sidekiq::Job

  def perform(collection_slug)
    DestroyCollection.new(collection_slug).execute
  end
end
