class GraphEntitiesController < ApplicationController
  before_action :set_collection
  before_action :set_entity, only: [:show, :summarize]

  def index
    # TODO: later
  end

  def show
    @collections = current_user.collections

    render :show
  end

  def summarize
    @entity.update!(summary_outdated: true)

    Graph::EntitySummarizer.new(Setting.entity_extraction_model).execute
  end

  private

  def set_entity
    @entity = GraphEntity.find(params[:id])
  end

  def set_collection
    @collection = Collection.find(params[:collection_id])
  end
end
