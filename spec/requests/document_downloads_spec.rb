require "rails_helper"

RSpec.describe "Document downloads", :unauthenticated, type: :request do
  subject(:request) { get download_document_path(document) }

  let(:document) { create(:document, :with_file) }
  let(:collection) { create(:collection) }

  # A reader reaches a document through a citation or a search result, so the
  # download has to work for them — but only for documents they could have been
  # cited, or the scoping on retrieval would be bypassable by guessing an id.
  context "when signed in as a plain user" do
    before { sign_in(create(:user)) }

    context "when the document is in a collection they can read" do
      before do
        create(:collection_membership, collection:, document:, origin: "manual")
        create(:collection_user, collection:, user: current_user)
      end

      it "hands over the file" do
        request
        expect(response).to have_http_status(:ok)
      end

      it "sends it as an attachment" do
        request
        expect(response.headers["Content-Disposition"]).to include("attachment")
      end
    end

    context "when the document is in a collection they cannot read" do
      before { create(:collection_membership, collection:, document:, origin: "manual") }

      it "is refused" do
        request
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the document is in no collection at all" do
      it "is refused, since nothing grants it" do
        request
        expect(response).to have_http_status(:not_found)
      end
    end

    it "still refuses the archive listing" do
      get documents_path
      expect(response).to redirect_to(root_path)
    end
  end

  context "when signed in as a curator" do
    before { sign_in(create(:user, :curator)) }

    # /unsorted is the queue for filing exactly these, and you can't file what
    # you can't open — but only for sources they manage.
    context "when the document is unfiled and from a source they manage" do
      before { create(:source_user, :admin, source: document.source, user: current_user) }

      it "hands over the file" do
        request
        expect(response).to have_http_status(:ok)
      end
    end

    context "when the document is unfiled and from a source they don't manage" do
      it "is refused" do
        request
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the document is filed in a collection they have no grant on" do
      before { create(:collection_membership, collection:, document:, origin: "manual") }

      it "is refused" do
        request
        expect(response).to have_http_status(:not_found)
      end
    end

    # Your own uploads are always yours: owning a source counts as
    # administering it, with no grant row needed.
    context "when the document came from a source they own" do
      let(:document) { create(:document, :with_file, source: create(:source, user: current_user)) }

      it "hands over the file" do
        request
        expect(response).to have_http_status(:ok)
      end
    end
  end

  context "when the document has no file attached" do
    let(:document) { create(:document) }

    before { sign_in(create(:user, :admin)) }

    it "is not found" do
      request
      expect(response).to have_http_status(:not_found)
    end
  end
end
