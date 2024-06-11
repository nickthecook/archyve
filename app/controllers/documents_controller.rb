class DocumentsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_collection
  before_action :set_document, only: [:show, :destroy, :vectorize]

  def show
    @collections = current_user.collections
    @pagy, @chunks = pagy(@document.chunks)

    return render "scrollable_list" if params[:page].present?

    render "show", locals: { document: @document }
  end

  def create
    @chunking_profile = ChunkingProfile.find_or_create_by(chunking_params)

    @document = Document.new(document_params.merge(chunking_profile: @chunking_profile))
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
    @document.deleting!

    DestroyJob.perform_async(@document.id)

    respond_to do |format|
      # Document will take care of it
      format.turbo_stream {}
      format.html { redirect_to collection_path(@collection) }
    end
  end

  def vectorize
    IngestJob.perform_async(@document.id)
  end

  private

  def chunking_params
    params.require(:chunking_profile).permit(:method, :size, :overlap)
  end

  def document_params
    params.permit(:file)
  end

  def set_document
    @document = Document.find(params[:id] || params[:document_id])
  end

  def set_collection
    @collection = Collection.find(params[:collection_id])
  end
end
