module V1
  class DocumentsController < ApiController
    include Pageable

    before_action :set_collection!
    before_action :set_document!, only: [:show]

    def index
      @pagy, @documents = pagy(@collection.documents, items:, page:)
      render json: { documents: @documents.map { |d| d.attributes.slice(*render_attributes) }, page: page_data }
    end

    def show
      render json: { document: @document.attributes.slice(*render_attributes) }
    end

    private

    def set_document!
      @document = Document.find_by(id: params[:id])

      render json: { error: "Document not found" }, status: :not_found if @document.nil?
    end

    def set_collection!
      @collection = Collection.find_by(id: params[:collection_id])

      render json: { error: "Collection not found" }, status: :not_found if @collection.nil?
    end

    def render_attributes
      %w[id collection_id user_id filename state vector_id chunking_profile_id]
    end
  end
end
