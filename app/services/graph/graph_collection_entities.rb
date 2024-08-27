module Graph
  class GraphCollectionEntities
    def initialize(collection)
      @collection = collection
    end

    def execute
      @collection.graphing!
      @collection.update!(process_steps: @collection.graph_entities.count)

      graph_collection

      @collection.graphed!
    rescue StandardError => e
      Rails.logger.error("#{e.class.name}: #{e.message}#{e.backtrace.join("\n")}")
      @collection.update!(state: :error)

      raise e
    end

    private

    def graph_collection
      @collection.graph_entities.each_with_index do |entity, index|
        @collection.update!(process_step: index)

        graph_node(entity)
      end
    end

    def graph_node(entity)
      node = node(entity)

      entity.relationships_from.each do |relationship|
        other_node = node(relationship.to_entity)
        relationship(node, other_node, relationship)
      end
    end

    def node(entity)
      existing = Nodes::Entity.find_by(entity_find_attrs(entity))
      return existing if existing.present?

      node = Nodes::Entity.from_model(entity)
      node.save!

      node
    end

    def relationship(from, to, relationship)
      Relationships::RelatesTo.create!(
        from_node: from,
        to_node: to,
        chunk: relationship.chunk.id,
        document: relationship.chunk.document.id,
        document_filename: relationship.chunk.document.filename,
        **relationship.attributes.slice(*relationship_attrs)
      )
    end

    def entity_find_attrs(entity)
      {
        name: entity.name,
        entity_type: entity.entity_type,
        collection: @collection.id,
      }
    end

    def relationship_attrs
      # TODO: either use strength from the model or remove this comment
      %w[description]
    end
  end
end
