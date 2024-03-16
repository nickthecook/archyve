class DocumentsController < ApplicationController
  before_action :set_collection

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
        render @message.conversation
      end
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
