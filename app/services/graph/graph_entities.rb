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
        relationship(node, other_node, relationship.attributes.slice(*relationship_attrs))
      end
    end

    def node(entity)
      Nodes::Entity.find_or_create_by!(entity.attributes.slice(*entity_attrs))
    end

    def relationship(from, to, attrs)
      # relationship = Relationships::RelatesTo.find_by(from_node: from, to_node: to, **attrs)
      # return relationship if relationship.present?
      Relationships::RelatesTo.create!(from_node: from, to_node: to, **attrs)
    end

    def entity_attrs
      %w[name entity_type summary collection collection_name]
    end

    def relationship_attrs
      # TODO: either use strength from the model or remove this comment
      %w[description]
    end
  end
end
