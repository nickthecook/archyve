require "rails_helper"

RSpec.describe "Documents", type: :request do
  # The one crumb above a document's own name. Matched as markup because several
  # of these labels — "Chat" especially — also appear in the top bar.
  def crumb(label, href)
    %(<a href="#{href}" class="hover:text-muted transition-colors">#{label}</a>)
  end

  describe "POST /documents" do
    subject(:request) { post documents_path, params: }

    before { allow(ProcessDocumentJob).to receive(:perform_later) }

    let(:file) { fixture_file_upload("sample.md", "text/markdown") }

    context "when uploading into a collection" do
      let(:collection) { create(:collection, name: "Handbook") }

      before { create(:collection_user, :curator, collection:, user: current_user) }
      let(:params) { { file:, collection_slug: collection.slug } }

      it "ingests the file and files it into the collection" do
        request
        expect(collection.reload.documents.count).to eq(1)
      end

      it "redirects back to the collection" do
        request
        expect(response).to redirect_to(collection_path(collection))
      end
    end

    # The global role says they may upload; the grant says where. Without the
    # second check a curator could file documents into any collection they
    # could merely see.
    context "when uploading into a collection they can only read" do
      let(:collection) { create(:collection, name: "Handbook") }
      let(:params) { { file: fixture_file_upload("sample.md", "text/markdown"), collection_slug: collection.slug } }

      before { create(:collection_user, collection:, user: current_user) }

      it "is refused" do
        request
        expect(response).to have_http_status(:not_found)
      end

      it "ingests nothing" do
        expect { request }.not_to change(Document, :count)
      end
    end

    context "when uploading with no collection" do
      let(:params) { { file: } }

      it "redirects to the new document" do
        request
        expect(response).to redirect_to(Document.last)
      end
    end

    # The uploader is asked per file, because the right answer is a property of
    # the file. Their answer is stored so a reprocess months later repeats it.
    context "when the uploader turns OCR off" do
      let(:params) { { file:, ocr: "0" } }

      it "records their answer on the document" do
        request
        expect(Document.last.ocr).to be(false)
      end
    end

    context "when the uploader leaves OCR on" do
      let(:params) { { file:, ocr: "1" } }

      it "records that too, rather than leaving it to be inferred later" do
        request
        expect(Document.last.ocr).to be(true)
      end
    end

    # The path that broke in production: upload a file the archive already
    # holds, with the OCR box unchecked. Dedup returned the existing row and
    # threw the answer away, so the page went on saying "ocr: on".
    context "when re-uploading a file already in the archive with OCR turned off" do
      let(:params) { { file:, ocr: "0" } }

      let!(:existing) do
        create(
          :document, :with_file,
          source: Sources::ManualUpload.create!(name: "Uploads", user: current_user),
          external_id: Digest::SHA256.hexdigest(file.tap(&:rewind).read),
          status: "failed"
        )
      end

      before { file.rewind }

      it "does not duplicate the document" do
        expect { request }.not_to change(Document, :count)
      end

      it "applies the new OCR choice to it" do
        request
        expect(existing.reload.ocr).to be(false)
      end

      it "runs it again, rather than leaving the old failure on the page" do
        request
        expect(ProcessDocumentJob).to have_received(:perform_later).with(existing)
      end
    end

    # An API client or a future caller that was never asked. Nil means "let the
    # source decide", which is different from having chosen `false`.
    context "when nothing says either way" do
      let(:params) { { file: } }

      it "leaves the document deferring to its source" do
        request
        expect(Document.last.ocr).to be_nil
      end
    end

    context "when no file is chosen for a collection upload" do
      let(:collection) { create(:collection) }

      before { create(:collection_user, :curator, collection:, user: current_user) }
      let(:params) { { collection_slug: collection.slug } }

      it "returns to the collection with an alert" do
        request
        expect(response).to redirect_to(collection_path(collection))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "GET /documents" do
    subject(:request) { get documents_path }

    let!(:document) { create(:document, status:) }

    before { create(:source_user, :admin, source: document.source, user: current_user) }

    context "when a listed document is still being processed" do
      let(:status) { "pending" }

      it "keeps polling, since nothing broadcasts to an index" do
        request
        expect(response.body).to include('progress-terminal-value="false"')
      end
    end

    context "when every listed document has settled" do
      let(:status) { "processed" }

      it "stops polling" do
        request
        expect(response.body).to include('progress-terminal-value="true"')
      end
    end
  end

  describe "GET /documents/:id" do
    subject(:request) { get document_path(document), headers: { "HTTP_REFERER" => referer } }

    let(:document) { create(:document, title: "Blueprint") }

    # Reaching a document means retrieving it through a collection or managing
    # the source that produced it; these examples are about the back link, so
    # they take the simpler of the two.
    before { create(:source_user, :admin, source: document.source, user: current_user) }

    context "when arrived from a collection" do
      let(:collection) { create(:collection, name: "Handbook") }
      let(:referer) { "http://www.example.com#{collection_path(collection)}" }

      before { create(:collection_user, collection:, user: current_user) }

      it "links back to that collection" do
        request
        expect(response.body).to include(crumb("Handbook", collection_path(collection)))
      end
    end

    context "when arrived from the flat documents list" do
      let(:referer) { "http://www.example.com#{documents_path}" }

      it "links back to all documents" do
        request
        expect(response.body).to include(crumb("All documents", documents_path))
      end
    end

    context "when arrived from search results" do
      let(:referer) { "http://www.example.com#{search_path}?q=hello" }

      it "links back to the search results, preserving the query" do
        request
        expect(response.body).to include(crumb("Search results", referer))
      end
    end

    context "when there is no referrer" do
      let(:referer) { nil }

      it "falls back to the Collections section home" do
        request
        expect(response.body).to include(crumb("Collections", collections_path))
      end
    end

    context "when arrived from a chat" do
      let(:conversation) { create(:conversation, user: current_user, title: "Framing a fireplace") }
      let(:referer) { "http://www.example.com#{conversation_path(conversation)}" }

      it "links back to that chat" do
        request
        expect(response.body).to include(crumb("Framing a fireplace", conversation_path(conversation)))
      end
    end

    # A conversation is private to its author, so an id belonging to someone
    # else's chat must not name it — or the back link leaks a title.
    context "when the referring chat belongs to someone else" do
      let(:conversation) { create(:conversation, user: create(:user), title: "Somebody else's question") }
      let(:referer) { "http://www.example.com#{conversation_path(conversation)}" }

      it "does not name it" do
        request
        expect(response.body).not_to include("Somebody else's question")
      end
    end
  end

  # The whole point of a citation: a reader follows it to the passage. Browsing
  # the archive is still a curator job, so this is the one document surface a
  # plain user reaches, and collection access is what decides it — not the role.
  describe "GET /documents/:id as a reader" do
    subject(:request) { get document_path(document) }

    let(:document) { create(:document, :with_file, title: "Blueprint") }

    before { sign_in(create(:user)) }

    context "when the document is in a collection they may read" do
      let(:collection) { create(:collection) }

      before do
        create(:collection_user, collection:, user: current_user)
        create(:collection_membership, collection:, document:)
      end

      it "renders" do
        request
        expect(response).to have_http_status(:ok)
      end

      it "shows the document" do
        request
        expect(response.body).to include("Blueprint")
      end

      # Collections is curator-only, so offering it would be a door that
      # bounces them — see Views::Chrome.
      # Downloading was already open to readers; the point of the citation
      # landing here is that they can read the cited passage *and* still leave
      # with the document, rather than having to find the passage themselves.
      it "offers the download" do
        request
        expect(response.body).to include(download_document_path(document))
      end

      it "sends them back to Chat" do
        request
        expect(response.body).to include(crumb("Chat", conversations_path))
      end

      it "does not offer Collections" do
        request
        expect(response.body).not_to include(%(href="#{collections_path}"))
      end
    end

    context "when the document is in a collection they may not read" do
      before { create(:collection_membership, collection: create(:collection), document:) }

      it "is not found" do
        request
        expect(response).to have_http_status(:not_found)
      end
    end

    # Unfiled documents are in nobody's corpus. A curator reaches them through
    # the source they manage; a reader has no such route.
    context "when the document is in no collection at all" do
      it "is not found" do
        request
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when they ask for the flat document list instead" do
      subject(:request) { get documents_path }

      it "still refuses" do
        request
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # The raw error is the curator's. A reader is told what happened to their
  # document in words; they are not handed the hostname of an embedding server.
  describe "GET /documents/:id when processing failed" do
    subject(:request) { get document_path(document) }

    let(:document) { create(:document, :with_file, title: "Blueprint") }

    before do
      document.record_failure!(
        Ingestion::Outcome.new(stage: "embed", kind: "unreachable", detail: "Faraday::ConnectionFailed: tensor:11434")
      )
    end

    context "as a curator who manages the source" do
      before { create(:source_user, :admin, source: document.source, user: current_user) }

      it "names the stage and kind" do
        request
        expect(response.body).to include("embed · unreachable")
      end

      it "shows the raw error" do
        request
        expect(response.body).to include("Faraday::ConnectionFailed: tensor:11434")
      end

      it "offers a reprocess" do
        request
        expect(response.body).to include(reprocess_document_path(document))
      end

      it "subscribes to the diagnostics stream as well as the document's own" do
        request
        expect(response.body.scan("<turbo-cable-stream-source").size).to eq(2)
      end
    end

    context "as a reader who reached it through a collection" do
      let(:collection) { create(:collection) }

      before do
        sign_in(create(:user))
        create(:collection_user, collection:, user: current_user)
        create(:collection_membership, collection:, document:)
      end

      it "explains the failure in plain words" do
        request
        expect(response.body).to include("A service Archyve depends on didn&#39;t respond")
      end

      it "does not show the raw error" do
        request
        expect(response.body).not_to include("Faraday::ConnectionFailed")
      end

      it "does not offer a reprocess" do
        request
        expect(response.body).not_to include(reprocess_document_path(document))
      end

      # Hiding the panel is not what keeps it private — never subscribing to
      # the stream it arrives on is, since a broadcast reaches every subscriber
      # and the page can't filter what it's already been sent. The curator's
      # page carries a second subscription; theirs must not.
      it "subscribes only to the document's own stream" do
        request
        expect(response.body.scan("<turbo-cable-stream-source").size).to eq(1)
      end
    end
  end

  # A reader searching a partly-converted document needs to know their results
  # are real but incomplete — not that the document is broken, and not nothing.
  describe "GET /documents/:id when part of the document couldn't be read" do
    subject(:request) { get document_path(document) }

    let(:document) { create(:document, :with_file, title: "Blueprint") }
    let(:collection) { create(:collection) }

    before do
      document.record_shortfall!(
        Ingestion::Outcome.new(stage: "extract", kind: "partial_extraction", detail: "docling reported page 2")
      )
      sign_in(create(:user))
      create(:collection_user, collection:, user: current_user)
      create(:collection_membership, collection:, document:)
    end

    it "still reads as processed, because it is" do
      request
      expect(response.body).to include("processed")
    end

    it "tells them what is missing and what still works" do
      request
      expect(response.body).to include("Part of this document couldn&#39;t be read")
    end

    it "keeps docling's account to the curator" do
      request
      expect(response.body).not_to include("docling reported page 2")
    end
  end

  describe "POST /documents/:id/reprocess" do
    subject(:request) { post reprocess_document_path(document) }

    let(:document) { create(:document, :with_file, status: "failed") }

    before { allow(ProcessDocumentJob).to receive(:perform_later) }

    context "when the document's source is theirs to manage" do
      before { create(:source_user, :admin, source: document.source, user: current_user) }

      it "re-runs the pipeline" do
        request
        expect(ProcessDocumentJob).to have_received(:perform_later).with(document)
      end

      # So the badge answers the click rather than sitting red until a worker
      # picks the job up.
      it "puts the document back in the queue" do
        request
        expect(document.reload.status).to eq("pending")
      end

      it "forgets the failure it is retrying" do
        document.record_failure!(Ingestion::Outcome.new(stage: "extract", kind: "unreachable", detail: "boom"))
        request
        expect(document.reload.outcome_kind).to be_nil
      end

      it "returns to the document" do
        request
        expect(response).to redirect_to(document)
      end
    end

    # Reaching a document is a reading right; re-ingesting one is work on the
    # source that produced it.
    context "when they can only read the document through a collection" do
      let(:collection) { create(:collection) }

      before do
        create(:collection_user, :curator, collection:, user: current_user)
        create(:collection_membership, collection:, document:)
      end

      it "is not found" do
        request
        expect(response).to have_http_status(:not_found)
      end

      it "runs nothing" do
        request
        expect(ProcessDocumentJob).not_to have_received(:perform_later)
      end
    end

    context "as a reader" do
      before { sign_in(create(:user)) }

      it "is refused by the role, before anything is looked up" do
        request
        expect(response).to redirect_to(root_path)
      end
    end

    context "when the document has been removed at its source" do
      let(:document) { create(:document, :with_file, status: "removed") }

      before { create(:source_user, :admin, source: document.source, user: current_user) }

      it "refuses to re-ingest what the archive has let go" do
        request
        expect(ProcessDocumentJob).not_to have_received(:perform_later)
        expect(flash[:alert]).to be_present
      end
    end

    context "when the document has no file behind it" do
      let(:document) { create(:document, status: "failed") }

      before { create(:source_user, :admin, source: document.source, user: current_user) }

      it "says there is nothing to do" do
        request
        expect(ProcessDocumentJob).not_to have_received(:perform_later)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "DELETE /documents/:id" do
    subject(:request) { delete document_path(document), headers: { "HTTP_REFERER" => collection_path(collection) } }

    let(:collection) { create(:collection, name: "Handbook") }
    let(:document) { create(:document, :with_file, source: create(:manual_upload_source, user: current_user)) }

    before { create(:collection_membership, collection:, document:, origin: "manual") }

    context "when the document's source is theirs to manage" do
      it "takes it out of the archive" do
        expect { request }.to change(Document, :count).by(-1)
      end

      it "takes its chunks and their embeddings with it" do
        create(:embedding, chunk: create(:chunk, document:))
        expect { request }.to change(Chunk, :count).by(-1).and change(Embedding, :count).by(-1)
      end

      # A tombstone would be a document nobody can reach and every sync ignores.
      it "leaves no membership behind" do
        expect { request }.to change(CollectionMembership, :count).by(-1)
      end

      it "returns to the page the button was on" do
        request
        expect(response).to redirect_to(collection_path(collection))
      end

      it "says what went" do
        request
        expect(flash[:notice]).to include("Sample Document")
      end
    end

    # The citation is a record of what the model was shown, and that is true
    # whatever later happened to the document.
    it "leaves an old chat's citations readable" do
      hit = create(:hit, chunk: create(:chunk, document:), document:)
      request
      expect(hit.reload.snippet).to be_present
      expect(hit.document_id).to be_nil
      expect(hit.title).to eq("Sample Document")
    end

    context "when a syncable source still feeds it" do
      let(:document) { create(:document, :with_file, source: create(:folder_source, user: current_user)) }

      it "refuses, because the next sync would put it back" do
        expect { request }.not_to change(Document, :count)
      end

      it "says where to delete it instead" do
        request
        expect(flash[:alert]).to include("Remove it there")
      end
    end

    # Reaching a document is a reading right; destroying one is work on the
    # source that produced it — the same asymmetry as reprocess.
    context "when they can only read the document through a collection" do
      let(:document) { create(:document, :with_file) }

      before { create(:collection_user, :admin, collection:, user: current_user) }

      it "is not found" do
        request
        expect(response).to have_http_status(:not_found)
      end

      it "deletes nothing" do
        expect { request }.not_to change(Document, :count)
      end
    end

    context "as a reader" do
      before { sign_in(create(:user)) }

      it "is refused by the role, before anything is looked up" do
        request
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
