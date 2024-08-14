class CleanGraphJob
  include Sidekiq::Job

  def perform(*args)
    collection_id = args.first

    # need to pass the ID here, since the Collection may be gone from the database
    Graph::CleanGraph.new(collection_id).execute
  end
end
