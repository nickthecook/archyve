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

    def create
      collection = Collection.new(**create_params)
      collection.update!(embedding_model: Setting.embedding_model)
      collection.generate_slug
      collection.save!

      render json: { collection: collection.attributes.slice!(*render_attributes) }
    end

    def destroy
      collection = Collection.find(params[:id])

      return render json: { error: "User cannot delete collection." } unless user_can_access_collection?(
        @client.user,
        collection
      )

      collection.destroy!

      render json: { collection: }, status: :ok
    end

    private

    def user_can_access_collection?(user, collection)
      user.collections.include?(collection)
    end

    def set_collection!
      @collection = Collection.find_by(id: params[:id])

      render json: { error: "Collection not found" }, status: :not_found if @collection.nil?
    end

    def create_params
      params.slice(:name).permit!
    end

    def render_attributes
      [:id, :name, :slug]
    end
  end
end
