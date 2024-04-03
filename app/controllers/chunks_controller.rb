class ChunksController < ApplicationController
  before_action :set_collection, only: [:show]
  before_action :set_document, only: [:show]
  before_action :set_chunk, only: [:show]

  NUM_NEIGHBOURS = 3

  def show
    return render_not_found unless @chunk

    @collections = current_user.collections

    @chunks = [
      *@chunk.previous(NUM_NEIGHBOURS),
      @chunk,
      *@chunk.next(NUM_NEIGHBOURS),
    ]

    render "collections/index", locals: { chunk: @chunk }
  end

  private

  def set_chunk
    @chunk = @document&.chunks&.find_by(id: params[:id])
  end

  def set_document
    @document = @collection.documents.find_by(id: params[:document_id])
  end

  def set_collection
    @collection = Collection.find_by(id: params[:collection_id])
  end
end
