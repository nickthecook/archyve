module V1
  class DocumentsController < ApiController
    before_action :set_collection!
    before_action :set_document!, only: [:show]

    def index
      render json: { documents: @collection.documents }
    end

    def show
      @document = Document.find(params[:id])
      if @document
        render json: { document: @document }
      else
        render json: { error: "Document not found" }, status: :not_found
      end
    end

    private

    def set_document!
      @document = Document.find(params[:id])

      render json: { error: "Document not found" }, status: :not_found if @document.nil?
    end

    def set_collection!
      @collection = Collection.find_by(id: params[:collection_id])

      render json: { error: "Collection not found" }, status: :not_found if @collection.nil?
    end
  end
end
