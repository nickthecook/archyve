class SearchMultipleJob
  include Sidekiq::Job

  sidekiq_options retry: false

  def perform(*args)
    collection_ids, query, dom_id = *args
    Rails.logger.info("Searching for #{query} in collections #{collection_ids}; updating #{dom_id}...")
    collections = Collection.find(collection_ids)

    Search::SearchMultiple.new(collections, dom_id:).search(query)
  end
end
