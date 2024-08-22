module V1
  class EntitiesController < ApiController
    before_action :set_entity

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
  end
end
