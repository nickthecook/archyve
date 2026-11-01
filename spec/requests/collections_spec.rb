require "rails_helper"

RSpec.describe "Collections", type: :request do
  describe "GET /collections" do
    subject(:request) { get collections_path }

    context "when collections exist" do
      let!(:collection) { create(:collection, name: "Handbook") }

      before { collection.grant_admin_to!(current_user) }

      it "renders them" do
        request
        expect(response.body).to include("Handbook")
      end
    end

    context "when a document has no active membership" do
      before { create(:document) }

      it "counts it under Unsorted" do
        request
        expect(response.body).to include("Unsorted")
      end
    end
  end

  describe "GET /collections/:slug" do
    subject(:request) { get collection_path(collection) }

    let(:collection) { create(:collection, name: "House") }

    before { collection.grant_admin_to!(current_user) }

    context "when the collection has an active document" do
      let(:document) { create(:document) }

      before { create(:collection_membership, collection:, document:, origin: "manual") }

      it "lists the document" do
        request
        expect(response.body).to include(document.title)
      end
    end

    context "when the collection is empty" do
      it "renders an empty state" do
        request
        expect(response.body).to include("No documents in this collection yet.")
      end
    end

    it "offers the People button to whoever administers the collection" do
      request
      expect(response.body).to include(collection_people_path(collection))
    end

    # Deleting is work on the source that produced the document, so the button
    # follows a grant there — not the one that lets you file things here.
    describe "the per-document Delete button" do
      before { create(:collection_membership, collection:, document:, origin: "manual") }

      context "when the document came from a source they manage" do
        let(:document) { create(:document, source: create(:manual_upload_source, user: current_user)) }

        it "is offered" do
          request
          expect(response.body).to include("Permanently delete “#{document.title}”")
        end
      end

      context "when the document came from a source they don't manage" do
        let(:document) { create(:document) }

        it "is not offered, because it would be refused" do
          request
          expect(response.body).not_to include("Permanently delete")
        end
      end

      # A sync would put it straight back, so the offer would be a lie.
      context "when a syncable source still feeds it" do
        let(:document) { create(:document, source: create(:folder_source, user: current_user)) }

        it "is not offered" do
          request
          expect(response.body).not_to include("Permanently delete")
        end
      end
    end

    # Where the "Processing…" flash sends you after an upload, so the badges here
    # have to catch up on their own. Two regions poll independently, so every
    # assertion has to name the one it means.
    describe "the live status regions" do
      def polling?(id)
        Nokogiri::HTML(response.body).at_css("##{id}")["data-progress-terminal-value"] == "false"
      end

      describe "the document list" do
        before { create(:collection_membership, collection:, document:, origin: "manual") }

        context "when a document in it is still being processed" do
          let(:document) { create(:document, status: "pending") }

          it "keeps polling" do
            request
            expect(polling?("collection_documents")).to be(true)
          end

          it "refreshes the header meter from the same response, so counts and badges agree" do
            request
            region = Nokogiri::HTML(response.body).at_css("#collection_documents")
            expect(JSON.parse(region["data-progress-also-value"])).to eq(["collection_meter"])
          end
        end

        context "when every document in it has settled" do
          let(:document) { create(:document, status: "processed") }

          it "stops polling" do
            request
            expect(polling?("collection_documents")).to be(false)
          end
        end

        # A failed document is done moving; polling forever would be a busy loop
        # waiting for a status only a re-upload can change.
        context "when a document failed" do
          let(:document) { create(:document, status: "failed") }

          it "stops polling" do
            request
            expect(polling?("collection_documents")).to be(false)
          end
        end
      end

      # The picker lists what *isn't* in this collection, so it can't take its cue
      # from the list above it — the common case is a file uploaded elsewhere,
      # still processing, that someone came here to file.
      describe "the Add documents picker" do
        context "when a document outside the collection is still being processed" do
          before { create(:document, status: "pending") }

          it "keeps polling, even though the collection's own documents have settled" do
            request
            expect(polling?("collection_documents")).to be(false)
            expect(polling?("collection_candidates")).to be(true)
          end
        end

        context "when every document outside the collection has settled" do
          before { create(:document, status: "processed") }

          it "stops polling" do
            request
            expect(polling?("collection_candidates")).to be(false)
          end
        end

        context "when there is nothing to add" do
          it "still renders the region, so the poll has a target if candidates appear" do
            request
            expect(Nokogiri::HTML(response.body).at_css("#collection_candidates")).to be_present
          end
        end
      end
    end
  end

  describe "POST /collections/:slug/documents" do
    subject(:request) { post collection_documents_path(collection), params: { document_ids: } }

    let(:collection) { create(:collection, name: "House") }

    before { collection.grant_admin_to!(current_user) }
    let(:document) { create(:document) }

    context "when adding a document not yet in the collection" do
      let(:document_ids) { [document.id] }

      it "adds it as a manual membership" do
        expect { request }.to change { collection.documents.count }.by(1)
      end

      it "redirects with a confirmation" do
        request
        expect(flash[:notice]).to include("Added 1 document")
      end
    end

    context "when adding a document already in the collection" do
      let(:document_ids) { [document.id] }

      before { create(:collection_membership, collection:, document:, origin: "manual") }

      it "is a no-op (idempotent), not an error" do
        expect { request }.not_to change { collection.documents.count }
      end
    end

    context "when nothing is selected" do
      let(:document_ids) { [] }

      it "says so rather than pretending to add" do
        request
        expect(flash[:notice]).to eq("No documents selected.")
      end
    end
  end

  describe "DELETE /collections/:slug/documents/:id" do
    subject(:request) { delete collection_document_path(collection, document) }

    before { collection.grant_admin_to!(current_user) }

    let(:collection) { create(:collection) }
    let(:document) { create(:document) }

    context "when the membership is manual" do
      let!(:membership) { create(:collection_membership, collection:, document:, origin: "manual") }

      it "removes the document from the collection" do
        expect { request }.to change { membership.reload.active? }.from(true).to(false)
      end
    end

    context "when the membership is source-fed" do
      before { create(:collection_membership, :feed, collection:, document:) }

      it "refuses and surfaces why" do
        request
        expect(flash[:alert]).to include("source")
      end
    end
  end

  describe "GET /collections/:slug as a curator" do
    subject(:request) { get collection_path(collection) }

    let(:collection) { create(:collection, name: "House") }

    before { create(:collection_user, :curator, collection:, user: current_user) }

    it "renders" do
      request
      expect(response).to have_http_status(:ok)
    end

    # Filing documents into a collection is not the same right as deciding who
    # may see it.
    it "offers no way to hand out access" do
      request
      expect(response.body).not_to include(collection_people_path(collection))
    end
  end

  describe "GET /collections/:slug as a reader" do
    subject(:request) { get collection_path(collection) }

    let(:collection) { create(:collection, name: "House") }

    before { create(:collection_user, collection:, user: current_user) }

    it "renders" do
      request
      expect(response).to have_http_status(:ok)
    end

    # Filing needs curator on the collection, so don't offer it.
    it "offers no upload" do
      request
      expect(response.body).not_to include("Upload")
    end

    it "offers no way to delete the collection" do
      request
      expect(response.body).not_to include("Delete this collection")
    end

    it "offers no way to hand out access" do
      request
      expect(response.body).not_to include(collection_people_path(collection))
    end
  end

  describe "DELETE /collections/:slug" do
    subject(:request) { delete collection_path(collection) }

    let(:collection) { create(:collection, name: "Doomed") }
    let!(:document) { create(:document) }

    before { create(:collection_membership, collection:, document:, origin: "manual") }

    context "when the curator administers the collection" do
      before { collection.grant_admin_to!(current_user) }

      it "deletes it" do
        expect { request }.to change(Collection, :count).by(-1)
      end

      # The shelf goes, not the books: documents belong to the source that
      # produced them.
      it "keeps the documents" do
        request
        expect(Document.exists?(document.id)).to be(true)
      end

      it "leaves a document that was only here unsorted" do
        request
        expect(Document.unsorted).to include(document)
      end
    end

    context "when the curator can only file documents into it" do
      before { create(:collection_user, :curator, collection:, user: current_user) }

      it "refuses" do
        expect { request }.not_to change(Collection, :count)
      end
    end

    context "when signed in as a system admin with no grant" do
      before { sign_in(create(:user, :admin)) }

      it "deletes it" do
        expect { request }.to change(Collection, :count).by(-1)
      end
    end
  end

  describe "PATCH /collections/:slug" do
    subject(:request) { patch collection_path(collection), params: { collection: { description: } } }

    let(:collection) { create(:collection, name: "Handbook") }
    let(:description) { "Security policy, on-call and incident review." }

    context "when they manage the collection" do
      before { collection.grant_admin_to!(current_user) }

      it "saves the description" do
        request
        expect(collection.reload.description).to eq(description)
      end

      it "returns to the collection" do
        request
        expect(response).to redirect_to(collection_path(collection))
      end

      it "shows it on the page" do
        request
        follow_redirect!
        expect(response.body).to include("Security policy, on-call and incident review.")
      end

      # Blank is absent, not a description that says nothing — the chat model is
      # handed no description at all for this collection.
      context "when it is cleared" do
        let(:description) { "   " }

        before { collection.update!(description: "Old text.") }

        it "forgets the old one" do
          request
          expect(collection.reload.description).to be_nil
        end
      end
    end

    # Hiding the form is not access control: describing a collection is
    # curation, and it takes a grant on this collection to do it.
    context "when they only read the collection" do
      before { create(:collection_user, collection:, user: current_user, role: :user) }

      it "refuses" do
        request
        expect(response).to have_http_status(:not_found)
      end

      it "changes nothing" do
        expect { request }.not_to change { collection.reload.description }
      end
    end
  end

  describe "POST /collections" do
    subject(:request) { post collections_path, params: { collection: { name: } } }

    context "when the name is valid" do
      let(:name) { "Design Docs" }

      it "creates the collection" do
        expect { request }.to change(Collection, :count).by(1)
      end

      it "redirects to the index" do
        request
        expect(response).to redirect_to(collections_path)
      end
    end

    context "when the name is blank" do
      let(:name) { "" }

      it "does not create a collection" do
        expect { request }.not_to change(Collection, :count)
      end

      it "redirects back with the error surfaced" do
        request
        expect(flash[:alert]).to be_present
      end
    end
  end
end
