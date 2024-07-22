module V1
  class ChunksController < ApiController
    before_action :set_chunk!, only: :show
    before_action :set_document!
    before_action :set_collection!

    include Pagy::Backend

    def index
      @chunks = @document.chunks.order(:id)
      @pagy, @posts = pagy(@chunks, items: count)

      render json: @posts.to_json
    end

    def show
      render json: @chunk.to_json
    end

    private

    def count
      if params[:count]
        params[:count].to_i
      else
        20
      end
    end

    def set_chunk!
      @chunk = Chunk.find_by(id: params[:id])

      render json: { error: "Chunk not found" }, status: :not_found if @chunk.nil?
    end

    def set_document!
      @document = Document.find_by(id: params[:document_id])

      render json: { error: "Document not found" }, status: :not_found if @document.nil?
    end

    def set_collection!
      @collection = Collection.find_by(id: params[:collection_id])

      render json: { error: "Collection not found" }, status: :not_found if @collection.nil?
    end
  end
end
