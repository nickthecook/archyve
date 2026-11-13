require "rails_helper"

RSpec.describe "Collections", type: :request do
  describe "GET /collections" do
    subject(:request) { get collections_path }

    context "when collections exist" do
      let!(:collection) { create(:collection, name: "Handbook") }

      before { collection.grant_manager_to!(current_user) }

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

    before { collection.grant_manager_to!(current_user) }

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

    context "when a source feeds the collection" do
      let(:source) { create(:folder_source, name: "Manuals") }
      let(:row) { Nokogiri::HTML(response.body).at_css("#collection_sources li").text }

      before do
        collection.sources << source
        create(:collection_membership, :feed, collection:, document: create(:document, source:, title: "Fed manual", status: "processed"))
        create(:collection_membership, :feed, collection:, document: create(:document, source:, title: "Broken manual", status: "failed"))
        create(:document, source:, status: "removed")
      end

      it "lists the source rather than its documents" do
        request
        expect(response.body).not_to include("Fed manual")
      end

      it "counts the source's live documents and the failed ones among them" do
        request
        expect(row).to include("2 documents · 1 failed")
      end

      it "doesn't show the empty state" do
        request
        expect(response.body).not_to include("No documents in this collection yet.")
      end

      context "when it has never been scanned" do
        it "says so" do
          request
          expect(row).to include("never scanned")
        end
      end

      context "when its last scan completed" do
        before { create(:source_sync, source:, started_at: 3.hours.ago, finished_at: 2.hours.ago) }

        it "says when" do
          request
          expect(row).to include("scanned about 2 hours ago")
        end
      end

      context "when its last scan failed" do
        before do
          create(:source_sync, source:, started_at: 3.days.ago, status: "completed")
          create(:source_sync, source:, started_at: 1.hour.ago, status: "failed")
        end

        it "reports the latest one" do
          request
          expect(row).to include("scan failed")
        end
      end
    end

    context "when a document was filed by hand alongside a fed source" do
      let(:document) { create(:document, title: "Hand-filed note") }

      before do
        collection.sources << create(:folder_source)
        create(:collection_membership, collection:, document:, origin: "manual")
      end

      it "lists it under Filed by hand" do
        request
        expect(response.body).to include("Filed by hand", "Hand-filed note")
      end
    end

    # A curator builds a collection; an admin decides who sees it.
    describe "the People button" do
      it "is not offered to a curator, even one who manages the collection" do
        request
        expect(response.body).not_to include(collection_people_path(collection))
      end

      context "when signed in as an admin" do
        before { sign_in(create(:user, :admin)) }

        it "is offered" do
          request
          expect(response.body).to include(collection_people_path(collection))
        end
      end
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

          it "refreshes the header meter and source counts from the same response, so they agree" do
            request
            region = Nokogiri::HTML(response.body).at_css("#collection_documents")
            expect(JSON.parse(region["data-progress-also-value"])).to eq(["collection_meter", "collection_sources"])
          end
        end

        context "when only a fed document is still being processed" do
          let(:document) { create(:document, status: "processed") }

          before do
            source = create(:folder_source)
            collection.sources << source
            create(:collection_membership, :feed, collection:, document: create(:document, source:, status: "pending"))
          end

          it "keeps polling, since the source counts are still moving" do
            request
            expect(polling?("collection_documents")).to be(true)
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

    before { collection.grant_manager_to!(current_user) }
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

    before { collection.grant_manager_to!(current_user) }

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

    before { create(:collection_user, :editor, collection:, user: current_user) }

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

    it "offers no way to delete the collection" do
      request
      expect(response.body).not_to include("Delete this collection")
    end
  end

  # An accessor grant is for chat. It gives a curator nothing here, the same as
  # it gives a visitor.
  describe "a curator with only an accessor grant" do
    let(:collection) { create(:collection, name: "House") }

    before { create(:collection_user, collection:, user: current_user, access: :accessor) }

    it "doesn't see the collection listed" do
      get collections_path
      expect(response.body).not_to include("House")
    end

    it "can't open the collection" do
      get collection_path(collection)
      expect(response).to have_http_status(:not_found)
    end

    it "doesn't see its documents listed" do
      create(:collection_membership, collection:, document: create(:document, title: "Floor plan"))
      get documents_path
      expect(response.body).not_to include("Floor plan")
    end

    it "can still draw on it in chat" do
      expect(Collection.readable_by(current_user)).to include(collection)
    end

    # Where a citation or a listed document leads, so it has to keep working.
    it "can still open a document in it" do
      document = create(:document, title: "Floor plan")
      create(:collection_membership, collection:, document:)
      get document_path(document)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "DELETE /collections/:slug" do
    subject(:request) { delete collection_path(collection) }

    let(:collection) { create(:collection, name: "Doomed") }
    let!(:document) { create(:document) }

    before { create(:collection_membership, collection:, document:, origin: "manual") }

    context "when the curator administers the collection" do
      before { collection.grant_manager_to!(current_user) }

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
      before { create(:collection_user, :editor, collection:, user: current_user) }

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
      before { collection.grant_manager_to!(current_user) }

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

    # Hiding the form is not access control: describing a collection takes a
    # manager grant on it.
    context "when they only edit the collection's contents" do
      before { create(:collection_user, :editor, collection:, user: current_user) }

      it "refuses" do
        request
        expect(response).to have_http_status(:not_found)
      end

      it "changes nothing" do
        expect { request }.not_to change { collection.reload.description }
      end

      it "doesn't offer the form" do
        get collection_path(collection)
        expect(response.body).not_to include("collection[description]")
      end
    end

    context "when they only read the collection" do
      before { create(:collection_user, collection:, user: current_user, access: :accessor) }

      it "refuses" do
        request
        expect(response).to have_http_status(:not_found)
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
