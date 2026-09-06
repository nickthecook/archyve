class DocumentsController < ApplicationController
  # Where the "back" link on a document points. A document is collection-agnostic
  # (it lives in many collections), so its URL carries no context — the only
  # signal of where the user came from is the referrer.
  BackLink = Data.define(:label, :href)

  def index
    render Views::Documents::Index.new(documents: Document.order(created_at: :desc))
  end

  def show
    render Views::Documents::Show.new(document: Document.find(params[:id]), back: back_link)
  end

  def create
    file = params[:file]
    return redirect_to(documents_path, alert: "Choose a file to upload.") if file.blank?

    document = Ingestion::DocumentUploader.call(file: file)
    redirect_to document, notice: "Uploaded “#{document.title}”. Processing…"
  end

  private

  # Resolve the back link from the referrer, so a document opened from a
  # collection returns to that collection, from search back to the results, etc.
  # Falls back to the Collections section home when the referrer is unknown.
  def back_link
    path = referer_path
    slug = path&.match(%r{\A/collections/([^/]+)\z})&.captures&.first

    if slug && (collection = Collection.find_by(slug:))
      BackLink.new(label: collection.name, href: collection_path(collection))
    elsif path == documents_path
      BackLink.new(label: "All documents", href: documents_path)
    elsif path == search_path
      BackLink.new(label: "Search results", href: request.referer)
    else
      BackLink.new(label: "Collections", href: collections_path)
    end
  end

  # The path of a same-origin referrer, or nil.
  def referer_path
    referer = request.referer
    return unless referer

    uri = URI(referer)
    uri.path if uri.host == request.host
  rescue URI::InvalidURIError
    nil
  end
end
