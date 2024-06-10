module V1
  class ChunksController < ApiController
    before_action :set_chunk!, only: :show

    def index
      @chunks = Chunk.all

      render json: @chunks
    end

    def show
      render json: @chunk
    end

    private

    def set_chunk!
      @chunk = Chunk.find_by(id: params[:id])

      render json: { "error": "Chunk not found" }, status: :not_found if @chunk.nil?
    end
  end
end
