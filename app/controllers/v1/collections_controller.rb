module V1
  class CollectionsController < ApiController
    before_action :set_collection!, only: [:show, :search]

    def index
      @collections = Collection.all

      render json: { collections: @collections.map { |c| c.attributes.slice(*render_attributes) } }, status: :ok
    end

    def show
      render json: { collection: @collection.attributes.slice(*render_attributes) }
    end

    def search
      query = params[:q]
      return render json: { error: "No query given" }, status: :bad_request if query.blank?

      render json: { hits: }
    end

    def create
      return render json: { error: "Name required in params." }, status: :bad_request unless create_params[:name]

      collection = Collection.new(**create_params)
      collection.update!(embedding_model: Setting.embedding_model)
      collection.generate_slug
      collection.save!

      render json: { collection: collection.attributes.slice(*render_attributes) }, status: :created
    rescue StandardError => e
      render json: { error: e }, status: :internal_server_error
    end

    def destroy
      collection = Collection.find(params[:id])

      return render json: { error: "User cannot delete collection." } unless user_can_access_collection?(
        @client.user,
        collection
      )

      collection.destroy!

      render json: { collection: collection.attributes.slice(*render_attributes) }, status: :ok
    end

    private

    def hits
      Api::GenerateSearchResults.new(
        @client.collections,
        base_url: request.base_url,
        browser_base_url:,
        num_results:,
        traceable: @client
      ).search(params[:q])
    end

    def num_results
      num_results = params[:num_results]&.to_i
      num_results || Setting.get(:num_chunks_to_include) || 10
    end

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
      %w[id name slug embedding_model_id]
    end
  end
end
