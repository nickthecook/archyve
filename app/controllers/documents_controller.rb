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

  def create
    @chunking_profile = ChunkingProfile.find_or_create_by(chunking_params)

    @document = new_document

    ChunkDocumentJob.perform_async(@document.id) unless @document.errored?

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
      format.html { redirect_to collection_path(@collection) }
    end
  end

  def vectorize
    ChunkDocumentJob.perform_async(@document.id)
  end

  def stop
    @document.update!(stop_jobs: true)
  end

  def start; end

  private

  def new_document
    document = Document.new(document_params.merge(chunking_profile: @chunking_profile))
    if params[:link].present?
      begin
        f = Tempfile.create(['web-', '.html'])
        f.puts HTTParty.get(params[:link])
        f.rewind
        document.file = f
        document.filename = file.path #File.basename(f.path)
      rescue StandardError
        document.update(state: :errored)
      end
    elsif params[:file]
      document.filename = params[:file].original_filename
    end
    document.collection = @collection
    document.user = current_user
    document.save!

    document
  end

  def chunking_params
    params.require(:chunking_profile).permit(:method, :size, :overlap)
  end

  def document_params
    params.permit(:file, :link)
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
