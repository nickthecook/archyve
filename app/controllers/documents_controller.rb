class DocumentsController < ApplicationController
  # Browsing the archive is an operator job; opening one document you were
  # pointed at is not. A reader arrives at `show` from a chat citation or a
  # search result, and both of those are already filtered to what they may
  # retrieve — gating it on the role as well would mean a citation that renders
  # as a link and then refuses, which is the thing Views::Chrome exists to avoid.
  #
  # What enforces access for `show` is the scope it looks the document up
  # through, not the role: `reachable_by` is the reader's own corpus, and
  # anything outside it raises RecordNotFound. Same asymmetry as `download`.
  require_role :operator, except: [:show, :download]

  # Where the "back" link on a document points. A document is collection-agnostic
  # (it lives in many collections), so its URL carries no context — the only
  # signal of where the user came from is the referrer.
  BackLink = Data.define(:label, :href)

  def index
    render Views::Documents::Index.new(documents: Document.reachable_by(Current.user).order(created_at: :desc))
  end

  def show
    render Views::Documents::Show.new(document: Document.reachable_by(Current.user).find(params[:id]), back: back_link)
  end

  # Uploading into a collection needs operator *on that collection*, not just
  # the global role, so the target is looked up through manageable_by. Finding
  # it unscoped and falling back to nil would be worse than refusing: the file
  # would silently land in Unsorted instead of where it was aimed.
  def create
    collection = target_collection
    file = params[:file]
    return redirect_to(collection || documents_path, alert: "Choose a file to upload.") if file.blank?

    document = Ingestion::DocumentUploader.call(
      file: file, user: Current.user, collections: Array(collection), ocr: ocr_choice
    )
    # Back to the collection when the upload targeted one, so the user sees it
    # appear; otherwise to the document itself.
    redirect_to collection || document, notice: upload_notice(document)
  end

  # Re-run the pipeline over a document that's already here.
  #
  # Scoped to sources this person manages, not to everything they can reach:
  # reaching a document is a reading right — a collection grant, a chat citation
  # — and re-ingesting one is work on the source that produced it. Same rule as
  # upload, and an admin manages everything, so nothing a system administrator
  # needs to fix is out of reach.
  def reprocess
    document = Document.where(source: Source.manageable_by(Current.user)).find(params[:id])
    return redirect_to(document, alert: "There's nothing to reprocess.") unless document.reprocessable?

    # Marked queued here rather than left to the job, so the page answers the
    # click. The job sets `processing` when a worker actually starts.
    document.queue_for_processing!
    ProcessDocumentJob.perform_later(document)
    redirect_to document, notice: "Reprocessing “#{document.title}”."
  end

  # Purge a document: out of every collection, out of the archive, chunks and
  # embeddings and file with it. Scoped like `reprocess` and for the same reason —
  # reaching a document is a reading right, destroying one is work on the source
  # that produced it.
  #
  # Back to wherever the button was: there are two of them, and the page they
  # were on is the one that has just changed.
  def destroy
    document = Document.where(source: Source.manageable_by(Current.user)).find(params[:id])
    return redirect_back(fallback_location: documents_path, alert: purge_refusal(document)) unless document.purgeable?

    title = document.title
    document.destroy
    redirect_back fallback_location: documents_path, notice: "Deleted “#{title}”."
  end

  # Hand over the bytes. Streamed through the controller rather than redirecting
  # to an Active Storage blob URL on purpose: a signed blob URL is reachable by
  # anyone holding it, which would put the archive's contents one forwarded link
  # away from anybody. This way the request is authenticated every time.
  #
  # Reads the whole file into memory, as Ingestion::DocumentUploader does on the
  # way in. Fine while documents are small; revisit the two together.
  def download
    document = Document.reachable_by(Current.user).find(params[:id])
    return head(:not_found) unless document.file.attached?

    send_data document.file.download,
      filename: document.file.filename.to_s,
      type: document.file.content_type,
      disposition: "attachment"
  end

  private

  # Says where the deletion has to happen instead, because "can't delete this"
  # on its own reads as a permissions problem when it isn't one.
  def purge_refusal(document)
    "“#{document.title}” is fed by #{document.source.name}. Remove it there and sync, " \
      "or detach the source from the collections it feeds."
  end

  # Uploading bytes the archive already holds doesn't re-ingest them, and may
  # not start any work at all — so don't promise any. `pending?` is the honest
  # test: it covers a fresh upload and a re-upload that asked for something new,
  # and excludes the one that was a no-op.
  def upload_notice(document)
    return "Uploaded “#{document.title}”. Processing…" if document.pending?

    "“#{document.title}” is already in Archyve — the same file, unchanged."
  end

  # The upload form always sends this (a hidden "0" behind the checkbox), so a
  # missing param means a caller that never asked — an API client, a spec —
  # and nil is the honest answer there: let the source decide.
  def ocr_choice
    return if params[:ocr].nil?

    ActiveModel::Type::Boolean.new.cast(params[:ocr])
  end

  def target_collection
    return if params[:collection_slug].blank?

    Collection.manageable_by(Current.user).find_by!(slug: params[:collection_slug])
  end

  # Resolve the back link from the referrer, so a document opened from a
  # collection returns to that collection, from search back to the results, and
  # from a chat citation back to the chat that cited it.
  def back_link
    path = referer_path
    slug = path&.match(%r{\A/collections/([^/]+)\z})&.captures&.first
    chat_id = path&.match(%r{\A/chat/([^/]+)\z})&.captures&.first

    if slug && (collection = Collection.readable_by(Current.user).find_by(slug:))
      BackLink.new(label: collection.name, href: collection_path(collection))
    elsif chat_id && (conversation = Current.user.conversations.find_by(id: chat_id))
      # Scoped to their own conversations, since a conversation is private to
      # its author — an id someone else's chat used must not name it here.
      BackLink.new(label: conversation.title.presence || "Chat", href: conversation_path(conversation))
    elsif path == documents_path
      BackLink.new(label: "All documents", href: documents_path)
    elsif path == search_path
      BackLink.new(label: "Search results", href: request.referer)
    else
      unreferred_back_link
    end
  end

  # Where "back" goes when the referrer tells us nothing. Collections is the
  # section a document belongs to, but a reader can't reach it, and the rule the
  # nav follows is that a link which bounces you is worse than no link — so they
  # get Chat, which is where they were sent from.
  def unreferred_back_link
    return BackLink.new(label: "Collections", href: collections_path) if Current.user.at_least?(:operator)

    BackLink.new(label: "Chat", href: conversations_path)
  end
end
