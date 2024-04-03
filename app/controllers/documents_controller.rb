class DocumentsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_collection
  before_action :set_document, only: [:show, :destroy, :vectorize]

  def show
    @collections = current_user.collections

    respond_to do |format|
      format.html { render "collections/index", locals: { document: @document } }
      format.json { render json: @document }
    end
  end

  def create
    @document = Document.new(document_params)
    @document.filename = params[:file].original_filename
    @document.collection = @collection
    @document.user = current_user
    @document.save!

    IngestJob.perform_async(@document.id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(:document_form, partial: "documents/form"),
          turbo_stream.append("#{dom_id(@collection)}-documents", partial: "shared/document"),
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

  def vectorize
    IngestJob.perform_async(@document.id)
  end

  private

  def document_params
    params.permit(:filename, :file)
  end

  def set_document
    @document = Document.find(params[:id] || params[:document_id])
  end

  def set_collection
    @collection = Collection.find(params[:collection_id])
  end
end
