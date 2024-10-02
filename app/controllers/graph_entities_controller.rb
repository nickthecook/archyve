class GraphEntitiesController < ApplicationController
  before_action :set_entity, only: [:show, :summarize]
  before_action :set_collection

  def index
    # TODO: later
  end

  def show
    @collections = current_user.collections
    @pagy, @descriptions = pagy(@entity.descriptions.order(:id))

    return render "scrollable_list" if params[:page].present?

    render :show
  end

  def summarize
    @entity.update!(summary_outdated: true)

    SummarizeEntityJob.perform_async(@entity.id)
  end

  private

  def set_entity
    @entity = GraphEntity.find(params[:entity_id] || params[:id])
  end

  def set_collection
    @collection = Collection.find(params[:collection_id])
  end
end
