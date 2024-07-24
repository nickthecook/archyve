class CleanGraphJob
  include Sidekiq::Job

  def perform(*args)
    collection_id = args.first
    collection = Collection.find(collection_id)

    Graph::CleanGraph.new(collection).clean!
  end
end
