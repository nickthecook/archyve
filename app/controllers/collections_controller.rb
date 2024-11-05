class CollectionsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_collection, only: %i[show update destroy search reprocess stop start]
  before_action :set_stop_jobs_false, only: %i[destroy reprocess start]

  def index
    @collections = current_user.collections
  end

  def show
    respond_to do |format|
      format.html do
        @collections = current_user.collections
        @show = "entities" if params[:show] == "entities"

        render :index
      end
    end
  end

  def new
    respond_to do |format|
      format.html do
        @collections = current_user.collections
        @collection = Collection.new
        render :index
      end
      format.json { render :new, status: :unprocessable_entity }
    end
  end

  def create
    @collection = Collection.new(collection_params)

    if @collection.save
      @collection.generate_slug
      CreateCollectionJob.perform_async(@collection.id)

      redirect_to collection_url(@collection)
    else
      @collections = current_user.collections
      flash[:error] = @collection.errors.full_messages
      render :index, status: :unprocessable_entity
    end
  end

  def update
    respond_to do |format|
      if @collection.update(collection_params)
        format.html { redirect_to collection_url(@collection) }
        format.json { render :show, status: :ok, location: @collection }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @collection.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @collection.destroy!

    DestroyChromaCollectionJob.perform_async(@collection.slug)
    CleanGraphJob.perform_async(@collection.id)

    respond_to do |format|
      format.html { redirect_to collections_url }
    end
  end

  def reprocess
    ReprocessCollectionJob.perform_async(@collection.id)
  end

  def stop
    @collection.update!(stop_jobs: true)
  end

  def start; end

  def search
    query = params[:query]
    dom_id = user_dom_id("search_results")

    SearchJob.perform_async(@collection.id, query, dom_id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            dom_id,
            partial: "search_results",
            locals: { query_id: dom_id }
          ),
          turbo_stream.replace(
            "#{dom_id(@collection)}-documents",
            partial: "search_results",
            locals: { query_id: dom_id }
          ),
          turbo_stream.replace(
            "search_form",
            partial: "search_form",
            locals: { collection: @collection, query: }
          ),
        ]
      end
    end
  end

  def global_search
    query = params[:query]
    dom_id = user_dom_id("global_search_results")
    collection_ids = current_user.collections.pluck(:id)

    return redirect_to(root_path, notice: "You don't have any collections yet.") if collection_ids.empty?

    SearchMultipleJob.perform_async(collection_ids, query, dom_id)

    render turbo_stream: [
      turbo_stream.replace(
        dom_id,
        partial: "global_search_results"
      ),
      turbo_stream.replace(
        user_dom_id("global_search_form"),
        partial: "global_search_form",
        locals: { collection: @collection, query: }
      ),
    ]
  end

  private

  def collection_params
    params.require(:collection).permit(:name, :graph_enabled, :embedding_model_id, :entity_extraction_model_id)
  end

  def set_collection
    @collection = Collection.find(params[:id] || params[:collection_id])
  end

  def set_stop_jobs_false
    @collection.update!(stop_jobs: false)
  end
end
