class DocumentsController < ApplicationController
  # Browsing the archive is an operator job; fetching one document you were
  # pointed at is not. See the download route.
  require_role :operator, except: :download

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

  # Uploading into a collection needs operator *on that collection*, not just
  # the global role, so the target is looked up through manageable_by. Finding
  # it unscoped and falling back to nil would be worse than refusing: the file
  # would silently land in Unsorted instead of where it was aimed.
  def create
    collection = target_collection
    file = params[:file]
    return redirect_to(collection || documents_path, alert: "Choose a file to upload.") if file.blank?

    document = Ingestion::DocumentUploader.call(file: file, user: Current.user, collections: Array(collection))
    # Back to the collection when the upload targeted one, so the user sees it
    # appear; otherwise to the document itself.
    redirect_to collection || document, notice: "Uploaded “#{document.title}”. Processing…"
  end

  # Hand over the bytes. Streamed through the controller rather than redirecting
  # to an Active Storage blob URL on purpose: a signed blob URL is reachable by
  # anyone holding it, which would put the archive's contents one forwarded link
  # away from anybody. This way the request is authenticated every time.
  #
  # Reads the whole file into memory, as Ingestion::DocumentUploader does on the
  # way in. Fine while documents are small; revisit the two together.
  def download
    document = Document.find(params[:id])
    return head(:not_found) unless document.file.attached?

    send_data document.file.download,
      filename: document.file.filename.to_s,
      type: document.file.content_type,
      disposition: "attachment"
  end

  private

  def target_collection
    return if params[:collection_slug].blank?

    Collection.manageable_by(Current.user).find_by!(slug: params[:collection_slug])
  end

  # Resolve the back link from the referrer, so a document opened from a
  # collection returns to that collection, from search back to the results, etc.
  # Falls back to the Collections section home when the referrer is unknown.
  def back_link
    path = referer_path
    slug = path&.match(%r{\A/collections/([^/]+)\z})&.captures&.first

    if slug && (collection = Collection.readable_by(Current.user).find_by(slug:))
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
