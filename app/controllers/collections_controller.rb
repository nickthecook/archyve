class CollectionsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_collection, only: %i[ show update destroy search ]

  def index
    @collections = Collection.all
  end

  def show
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("collection", partial: "collection") }
      format.html do
        @collections = Collection.all
        render :index
      end
    end
  end

  def create
    @collection = Collection.new
    @collection.name ||= "New collection"
    @collection.save!
    @collection.generate_slug

    respond_to do |format|
      if @collection.save
        format.html { redirect_to collection_url(@collection) }
        format.json { render :show, status: :created, location: @collection }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @collection.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @collection.update(collection_params)
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(@collection),
            partial: "collection_list_item",
            locals: { collection: @collection }
          )
        end
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
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@collection) }
      format.html { redirect_to collections_url }
    end
  end

  def search
    query = params[:query]
    dom_id = "search_results"

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
            locals: { collection: @collection }
          )
        ]
      end
    end
  end

  private

  def collection_params
    params.require(:collection).permit(:name, :slug)
  end

  def set_collection
    @collection = Collection.find(params[:id] || params[:collection_id])
  end
end
