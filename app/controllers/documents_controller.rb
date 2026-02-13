class DocumentsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_collection
  before_action :set_document, only: %i[show destroy vectorize stop start]
  before_action :set_stop_jobs_false, only: %i[destroy vectorize start]

  def show
    @collections = current_user.collections
    @pagy, @chunks = pagy(@document.chunks.order(:id))

    return render "scrollable_list" if params[:page].present?

    render "show", locals: { document: @document }
  end

  def new
    @collections = current_user.collections
    @document = Document.new(collection_id: @collection.id)
  end

  def create
    @chunking_profile = ChunkingProfile.find_or_create_by(chunking_params)
    @document = document_from_params
    Mediator.ingest(@document)
    redirect_to @document.collection
  end

  def destroy
    if @document.original_document?
      @document.deleting!

      DestroyDocumentJob.perform_async(@document.id)

      respond_to do |format|
        format.html { redirect_to collection_path(@collection) }
      end
    else
      flash[:error] = ["Not an original (top-level) document; cannot delete."]
      redirect_to @document.collection
    end
  end

  def vectorize
    Mediator.ingest(@document)

    respond_to do |format|
      format.html { redirect_to collection_path(@collection) }
    end
  rescue Mediator::IngestError => e
    flash[:error] = ["Unable to re-process/ingest document: #{e.message}"]
    redirect_to @document.collection
  end

  def stop
    @document.update!(stop_jobs: true)
  end

  def start; end

  private

  def document_from_params
    body = document_params[:body]
    document = Document.new(document_params.except(:body).merge(chunking_profile: @chunking_profile))
    if document_params[:file].present?
      document.filename = document_params[:file].original_filename
    elsif document_params[:link].present?
      document.title = document_params[:link]
    elsif body.present?
      document.file.attach(
        io: StringIO.new(document_params[:body]),
        filename: "fact-#{Time.current.to_i}.txt",
        content_type: "text/plain"
      )
      document.filename = document.file.filename.to_s
      document.title = body.truncate(80)
    end
    document.collection = @collection
    document.user = current_user
    document.save!

    document
  end

  def chunking_params
    params.fetch(:chunking_profile, { method: "bytes", size: 1000, overlap: 0 }).permit(:method, :size, :overlap)
  end

  def document_params
    params.require(:document).permit(:file, :link, :filename, :body)
  end

  def set_document
    @document = Document.find(params[:id] || params[:document_id])
  end

  def set_collection
    @collection = Collection.find(params[:collection_id])
  end

  def set_stop_jobs_false
    @document.update!(stop_jobs: false)
  end
end
