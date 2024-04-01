module V1
  class DocumentsController < ApiController
    def index
      @documents = Document.all

      render json: @documents
    end

    def show
      @document = Document.find(params[:id])
      if @document
        render json: @document
      else
        render json: { error: "Document not found" }, status: :not_found
      end
    end
  end
end
