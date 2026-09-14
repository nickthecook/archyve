require "rails_helper"

RSpec.describe "Documents", type: :request do
  describe "POST /documents" do
    subject(:request) { post documents_path, params: }

    before { allow(ProcessDocumentJob).to receive(:perform_later) }

    let(:file) { fixture_file_upload("sample.md", "text/markdown") }

    context "when uploading into a collection" do
      let(:collection) { create(:collection, name: "Handbook") }

      before { create(:collection_user, :operator, collection:, user: current_user) }
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
    # second check an operator could file documents into any collection they
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

    context "when no file is chosen for a collection upload" do
      let(:collection) { create(:collection) }

      before { create(:collection_user, :operator, collection:, user: current_user) }
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
        expect(response.body).to include("← Handbook").and include(collection_path(collection))
      end
    end

    context "when arrived from the flat documents list" do
      let(:referer) { "http://www.example.com#{documents_path}" }

      it "links back to all documents" do
        request
        expect(response.body).to include("← All documents")
      end
    end

    context "when arrived from search results" do
      let(:referer) { "http://www.example.com#{search_path}?q=hello" }

      it "links back to the search results, preserving the query" do
        request
        expect(response.body).to include("← Search results").and include("#{search_path}?q=hello")
      end
    end

    context "when there is no referrer" do
      let(:referer) { nil }

      it "falls back to the Collections section home" do
        request
        expect(response.body).to include("← Collections").and include(collections_path)
      end
    end

    context "when arrived from a chat" do
      let(:conversation) { create(:conversation, user: current_user, title: "Framing a fireplace") }
      let(:referer) { "http://www.example.com#{conversation_path(conversation)}" }

      it "links back to that chat" do
        request
        expect(response.body).to include("← Framing a fireplace").and include(conversation_path(conversation))
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
  # the archive is still an operator job, so this is the one document surface a
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

      # Collections is operator-only, so offering it would be a door that
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
        expect(response.body).to include("← Chat").and include(conversations_path)
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

    # Unfiled documents are in nobody's corpus. An operator reaches them through
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
end
