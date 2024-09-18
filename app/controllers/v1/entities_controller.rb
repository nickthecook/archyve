module V1
  class EntitiesController < ApiController
    before_action :set_collection!
    before_action :set_entity, only: [:show]

    def index
      render json: { entities: @collection.graph_entities }
    end

    def show
      render json: entity_body
    end

    private

    def entity_body
      attributes = @entity.attributes.to_h
      attributes["content"] = attributes["summary"]
      attributes.delete("summary")

      attributes
    end

    def set_entity
      @entity = GraphEntity.find(params[:id])
    end

    def set_collection!
      @collection = Collection.find_by(id: params[:collection_id])

      render json: { error: "Collection not found" }, status: :not_found if @collection.nil?
    end
  end
end
