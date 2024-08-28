class CreateCollection
  def initialize(collection)
    @collection = collection
  end

  def execute
    chromadb.create_collection(@collection.slug)
  end

  private

  def chromadb
    @chromadb ||= Chromadb::Client.new
  end
end
