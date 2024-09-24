module V1
  class EntitiesController < ApiController
    before_action :set_collection!
    before_action :set_entity!, only: [:show]

    def index
      render json: { entities: @collection.graph_entities.map { |e| body_for(e) } }
    end

    def show
      render json: body_for(@entity)
    end

    private

    def body_for(entity)
      body = entity.attributes.to_h.slice(*render_attributes)
      body["collection"] = entity.collection.id

      body
    end

    def set_entity!
      @entity = GraphEntity.find(params[:id])

      render json: { error: "Entity not found" }, status: :not_found if @entity.nil?
    end

    def set_collection!
      @collection = Collection.find_by(id: params[:collection_id])

      render json: { error: "Collection not found" }, status: :not_found if @collection.nil?
    end

    def render_attributes
      %w[id name entity_type collection summary summary_outdated vector_id created_at updated_at]
    end
  end
end
