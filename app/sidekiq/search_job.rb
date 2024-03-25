class SearchJob
  include Sidekiq::Job

  sidekiq_options retry: false

  def perform(*args)
    collection_id, query, dom_id = args
    
    collection = Collection.find(collection_id)

    Search.new(collection).search(query, dom_id)
  end
end
