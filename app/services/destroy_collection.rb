class DestroyCollection
  def initialize(collection)
    @collection = collection
  end

  def execute
    chromadb.delete_collection(@collection.slug)

    @collection.destroy!
  end

  private

  def chromadb
    @chromadb ||= Chromadb::Client.new
  end
end
