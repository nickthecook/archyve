class CleanGraphJob
  include Sidekiq::Job

  def perform(*args)
    collection_id = args.first

    Graph::CleanGraph.new(collection_id).clean!
  end
end
