class DestroyCollectionJob
  include Sidekiq::Job

  def perform(*args)
    collection = Collection.find(args.first)

    DestroyCollection.new(collection).execute
  end
end
