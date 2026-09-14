require "rails_helper"

RSpec.describe "Unsorted", type: :request do
  describe "GET /unsorted" do
    subject(:request) { get unsorted_path }

    context "when a document is in no collection" do
      let!(:document) { create(:document, title: "Loose Note") }

      before { create(:source_user, :admin, source: document.source, user: current_user) }

      it "lists it" do
        request
        expect(response.body).to include("Loose Note")
      end
    end

    # The queue is for filing what you produced, not everything nobody filed.
    context "when an unfiled document came from a source they don't manage" do
      let!(:document) { create(:document, title: "Someone Else's Note") }

      it "is not listed" do
        request
        expect(response.body).not_to include("Someone Else's Note")
      end
    end

    context "when a document is in a collection" do
      let(:document) { create(:document, title: "Filed Note") }

      before { create(:collection_membership, document:, collection: create(:collection), origin: "manual") }

      it "excludes it" do
        request
        expect(response.body).not_to include("Filed Note")
      end
    end

    describe "the live status region" do
      let!(:document) { create(:document, status:) }

      before { create(:source_user, :admin, source: document.source, user: current_user) }

      context "when a document is still being processed" do
        let(:status) { "pending" }

        it "keeps polling" do
          request
          expect(response.body).to include('progress-terminal-value="false"')
        end

        # The filter hides rows in place, so the poll has to be able to put the
        # query box back with them.
        it "polls the whole sorter, filter and all, not just the list" do
          request
          expect(response.body).to include('data-controller="list-filter progress"')
        end
      end

      context "when every document has settled" do
        let(:status) { "processed" }

        it "stops polling" do
          request
          expect(response.body).to include('progress-terminal-value="true"')
        end
      end
    end
  end

  describe "POST /unsorted/assign" do
    subject(:request) { post assign_unsorted_path, params: { collection_slug: collection.slug, document_ids: } }

    let(:collection) { create(:collection, name: "Handbook") }
    let(:document) { create(:document) }

    before { create(:collection_user, :operator, collection:, user: current_user) }

    context "when documents are selected" do
      let(:document_ids) { [document.id] }

      it "adds them to the collection (so they leave Unsorted)" do
        expect { request }.to change { collection.documents.count }.by(1)
      end

      it "confirms the assignment" do
        request
        expect(flash[:notice]).to include("Added 1 document to Handbook")
      end
    end

    # Filing is a change to what a collection's readers see, so it needs
    # operator on the destination and not merely the global role.
    context "when the destination is one they can only read" do
      let(:document_ids) { [document.id] }

      # Replaces the operator grant above with a reader's.
      before { CollectionUser.find_by!(collection:, user: current_user).update!(role: :user) }

      it "is refused" do
        request
        expect(response).to have_http_status(:not_found)
      end

      it "files nothing" do
        expect { request }.not_to change(CollectionMembership, :count)
      end
    end

    context "when nothing is selected" do
      let(:document_ids) { [] }

      it "says so" do
        request
        expect(flash[:notice]).to eq("No documents selected.")
      end
    end
  end
end
