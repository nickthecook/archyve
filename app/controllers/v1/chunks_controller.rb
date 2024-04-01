module V1
  class ChunksController < ApiController
    def index
      @chunks = Chunk.all

      render json: @chunks
    end

    def show
      @chunk = Chunk.find(params[:id])

      return render json: { "error": "Chunk not found" }, status: :not_found unless @chunk

      render json: @chunk
    end
  end
end
