module Graph
  class CleanCollectionEntityVectors
    def initialize(collection)
      @collection = collection
    end

    def execute
      @collection.graph_entities.each do |entity|
        next if entity.vector_id.blank?

        chromadb.delete_documents(collection_id, [entity.vector_id])
      end
    end

    private

    def collection_id
      @collection_id ||= chromadb.collection_id(@collection.slug)
    end

    def chromadb
      @chromadb ||= Chromadb::Client.new(traceable: @collection)
    end
  end
end
