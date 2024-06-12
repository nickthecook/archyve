class DeleteChromaCollection
  def initialize(collection_slug)
    @collection_slug = collection_slug
  end

  def execute
    chromadb.delete_collection(@collection_slug)
  rescue Chromadb::ResponseError => e
    raise unless e.message.match?(/does not exist/)
  end

  private

  def chromadb
    @chromadb ||= Chromadb::Client.new
  end
end
