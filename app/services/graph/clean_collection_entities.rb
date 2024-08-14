module Graph
  class CleanCollectionEntities
    def initialize(collection)
      @collection = collection
    end

    def execute
      remove_entities_without_descriptions
    end

    private

    def remove_entities_without_descriptions
      Rails.logger.info("CleanCollectionEntities: Removing #{entities_without_descriptions.count} entities...")

      entities_without_descriptions.each do |entity|
        remove_node(entity)
        entity.destroy!
      end
    end

    def remove_node(entity)
      node = entity.graph_node

      if node.nil?
        Rails.logger.info("CleanCollectionEntities: No Node found in graph DB for entity #{entity.id}; skipping...")
        return
      end

      node.destroy
    end

    def entities_without_descriptions
      @entities_without_descriptions ||= @collection.graph_entities.where.missing(:descriptions)
    end
  end
end
