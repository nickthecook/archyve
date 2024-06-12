class DestroyChromaCollectionJob
  include Sidekiq::Job

  def perform(*args)
    collection_slug = args.first
    DeleteChromaCollection.new(collection_slug).execute
  end
end
