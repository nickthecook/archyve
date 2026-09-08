require "rails_helper"

RSpec.describe "Collection sources", :unauthenticated, type: :request do
  let(:root) { Dir.mktmpdir("archyve-collection-sources-spec") }
  let(:operator) { create(:user, :operator) }
  let(:collection) { create(:collection, name: "House manuals") }
  let(:source) { create(:folder_source, name: "House", path: root) }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  before do
    sign_in(operator)
    create(:collection_user, :operator, collection:, user: operator)
  end

  describe "POST /collections/:slug/sources" do
    subject(:request) { post collection_sources_path(collection), params: { source_id: source.id } }

    # The whole point of the source `user` role: IT keeps the credentials, and
    # the team that owns the collection decides what it draws on.
    context "when they hold only a `user` grant on the source" do
      before { create(:source_user, source:, user: operator, role: "user") }

      it "attaches it" do
        request
        expect(collection.reload.sources).to include(source)
      end

      it "does not let them configure the source" do
        get edit_source_path(source)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when they hold no grant on the source at all" do
      it "is refused" do
        request
        expect(response).to have_http_status(:not_found)
      end

      it "attaches nothing" do
        expect { request }.not_to(change { collection.reload.sources.count })
      end
    end

    context "when the source already has documents" do
      let!(:document) { create(:document, source:, status: "processed") }

      before { create(:source_user, source:, user: operator, role: "user") }

      # Attaching has to file what is already there; sync only files what it
      # re-imports, so the collection would otherwise stay empty until every
      # document happened to change.
      it "files them into the collection" do
        request
        expect(collection.reload.documents).to include(document)
      end
    end

    context "when they only read the collection" do
      before do
        CollectionUser.find_by!(collection:, user: operator).update!(role: :user)
        create(:source_user, source:, user: operator, role: "user")
      end

      it "is refused" do
        request
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /collections/:slug/sources/:id" do
    subject(:request) { delete collection_source_path(collection, source) }

    let!(:document) { create(:document, source:, status: "processed") }

    before { source.update_fed_collections([collection]) }

    # Detaching needs no grant on the source: you may always stop drawing on
    # something, and a revoked source grant shouldn't leave a collection
    # permanently fed by something its owner can't detach.
    it "detaches it" do
      request
      expect(collection.reload.sources).not_to include(source)
    end

    it "retracts the memberships the source had asserted" do
      request
      expect(CollectionMembership.find_by(document:, collection:)).not_to be_active
    end

    it "does not destroy the documents" do
      request
      expect(Document.exists?(document.id)).to be(true)
    end

    # update_fed_collections diffs the source's full list, so detaching from
    # one collection must not disturb the others.
    context "when the source also feeds a collection they can't see" do
      let(:theirs) { create(:collection, name: "Theirs") }

      before { source.update_fed_collections([collection, theirs]) }

      it "leaves that feed alone" do
        request
        expect(source.reload.collections).to include(theirs)
      end
    end
  end
end
