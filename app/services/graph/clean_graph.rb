module Graph
  class CleanGraph
    def initialize(collection = nil)
      @collection = collection
    end

    def clean!
      Nodes::Entity.find_each do |entity|
        entity.destroy if @collection.present? && entity.collection == @collection.id
      end
    end
  end
end
