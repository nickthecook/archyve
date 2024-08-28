class DestroyCollection
  def initialize(collection_slug)
    @collection_slug = collection_slug
  end

  def execute
    chromadb.delete_collection(@collection_slug)
  end
end
