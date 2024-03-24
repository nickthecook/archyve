class DocumentsController < ApplicationController
  before_action :set_collection
  before_action :set_document, only: [:show, :destroy]

  def create
    @document = Document.new(document_params)
    @document.filename = params[:file].original_filename
    @document.collection = @collection
    @document.user = current_user
    @document.save!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(:document_form, partial: "documents/form"),
        ]
      end
      format.html do
        render @document.collection
      end
    end
  end

  def destroy
    @document.destroy!

    respond_to do |format|
      format.html { redirect_to collection_path(@collection) }
    end
  end

  private

  def document_params
    params.permit(:filename, :file)
  end

  def set_document
    @document = Document.find(params[:id])
  end

  def set_collection
    @collection = Collection.find(params[:collection_id])
  end
end
