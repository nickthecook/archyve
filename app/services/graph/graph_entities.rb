module Graph
  class GraphEntities
    def initialize(collection)
      @collection = collection
    end

    def graph
      @collection.entities.each do |entity|
        graph_node(entity)
      end
    end

    private

    def graph_node(entity)
      node = node(entity)

      entity.relationships_from.each do |relationship|
        other_node = node(relationship.to)
        relationship(node, other_node, relationship)
      end
    end

    def node(entity)
      existing = Nodes::Entity.find_by(entity.attributes.slice(*entity_find_attrs))
      return existing if existing.present?

      node = Nodes::Entity.from_model(entity)
      node.save!

      node
    end

    def relationship(from, to, relationship)
      Relationships::RelatesTo.create!(
        from_node: from,
        to_node: to,
        **relationship.attributes.slice(*relationship_attrs)
      )
    end

    def entity_find_attrs
      %w[name entity_type summary collection collection_name]
    end

    def relationship_attrs
      # TODO: either use strength from the model or remove this comment
      %w[description]
    end
  end
end
