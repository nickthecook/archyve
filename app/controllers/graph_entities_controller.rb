class GraphEntitiesController < ApplicationController
  before_action :set_entity, only: [:show, :summarize, :search]
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

  def search
    @collections = current_user.collections
    @pagy, @descriptions = pagy(
      @entity.descriptions.where("description LIKE ?", "%#{params[:query]}%"),
      request_path: collection_entity_search_path(@entity.collection, @entity)
    )

    return render "scrollable_list" if params[:page].present?

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            "#{@entity.class.name.underscore}_#{@entity.id}-descriptions",
            partial: "graph_entities/descriptions",
            locals: { descriptions: @descriptions }
          ),
        ]
      end
    end
  end

  private

  def set_entity
    @entity = GraphEntity.find(params[:entity_id] || params[:id])
  end

  def set_collection
    @collection = Collection.find(params[:collection_id])
  end
end
