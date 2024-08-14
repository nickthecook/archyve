module Graph
  class CleanGraph
    def initialize(collection_id = nil)
      @collection_id = collection_id
    end

    def execute
      Nodes::Entity.find_each do |entity|
        entity.destroy if entity.collection == @collection_id
      end
    end
  end
end
