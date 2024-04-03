class SearchMultipleJob
  include Sidekiq::Job

  sidekiq_options retry: false

  def perform(*args)
    collection_ids, query, dom_id = *args
    collections = Collection.find(collection_ids)

    Search::SearchMultiple.new(collections, dom_id:).search(query)
  end
end
