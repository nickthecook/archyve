module V1
  class CollectionsController < ApiController
    before_action :set_collection!, only: [:show, :search]

    def index
      @collections = Collection.all

      render json: @collections
    end

    def show
      render json: @collection
    end

    def search
      query = params[:q]
      return render json: { error: "No query given" }, status: :bad_request if query.blank?

      render json: { hits: Api::Search.new(@collection, base_url: request.base_url).search(query) }
    end

    private

    def set_collection!
      @collection = Collection.find_by(id: params[:id])

      render json: { error: "Collection not found" }, status: :not_found if @collection.nil?
    end
  end
end
