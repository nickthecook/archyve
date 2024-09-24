module V1
  class ChunksController < ApiController
    before_action :set_chunk!, only: :show
    before_action :set_document!
    before_action :set_collection!

    include Pageable

    def index
      @pagy, @chunks = pagy(@document.chunks.order(:id), items:, page:)

      render json: { chunks: @chunks.map { |c| body_for(c) }, page: page_data }
    end

    def show
      render json: @chunk.to_json
    end

    private

    def body_for(chunk)
      body = chunk.attributes.to_h.slice(*render_attributes)
      remove_id_suffix_from("document", body)

      body
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

    def render_attributes
      %w[id document_id content embedding_content embeddings entities_extracted vector_id created_at updated_at]
    end
  end
end
