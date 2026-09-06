class DocumentsController < ApplicationController
  def index
    render Views::Documents::Index.new(documents: Document.order(created_at: :desc))
  end

  def show
    render Views::Documents::Show.new(document: Document.find(params[:id]))
  end

  def create
    file = params[:file]
    return redirect_to(documents_path, alert: "Choose a file to upload.") if file.blank?

    document = Ingestion::DocumentUploader.call(file: file)
    redirect_to document, notice: "Uploaded “#{document.title}”. Processing…"
  end
end
