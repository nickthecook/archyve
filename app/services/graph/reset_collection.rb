module Graph
  class ResetCollection
    def initialize(collection)
      @collection = collection
    end

    def execute
      @collection.graph_entities.update!(summary_outdated: true)
    end
  end
end
