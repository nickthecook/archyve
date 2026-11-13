require "rails_helper"

RSpec.describe "Collection people", :unauthenticated, type: :request do
  let(:collection) { create(:collection, name: "Handbook") }
  let(:curator) { create(:user, :curator) }
  let(:admin) { create(:user, :admin) }

  describe "GET /collections/:slug/people" do
    subject(:request) { get collection_people_path(collection) }

    context "when signed in as an admin" do
      before { sign_in(admin) }

      it "renders" do
        request
        expect(response).to have_http_status(:ok)
      end

      it "says which kind of thing it is managing" do
        request
        expect(response.body).to include("Collection")
      end

      # A grant to a system admin is a no-op — they reach every collection
      # already — and it was that no-op that sorted first in the person list.
      it "does not offer system admins as candidates" do
        other = create(:user, :admin, email_address: "boss@example.com")
        request
        expect(response.body).not_to include(other.email_address)
      end

      it "requires a person to be chosen rather than defaulting to one" do
        create(:user)
        request
        expect(response.body).to include("Choose someone")
      end

      context "when a group exists" do
        before { create(:group, name: "Human Resources") }

        it "offers it" do
          request
          expect(response.body).to include("Human Resources")
        end
      end

      context "when a group has been given access" do
        let(:group) { create(:group) }

        before { create(:collection_group, collection:, group:) }

        it "links to the group" do
          request
          expect(response.body).to include(settings_group_path(group))
        end
      end
    end

    # A curator builds a collection; an admin decides who sees it.
    context "when signed in as a curator who manages the collection" do
      before do
        sign_in(curator)
        create(:collection_user, :manager, collection:, user: curator)
      end

      it "is refused" do
        request
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /collections/:slug/people" do
    subject(:request) { post collection_people_path(collection), params: { user_id: target.id, access: "accessor" } }

    let(:target) { create(:user) }

    context "when signed in as an admin" do
      before { sign_in(admin) }

      it "grants access" do
        expect { request }.to change { collection.collection_users.count }.by(1)
      end

      context "when they already have a grant" do
        before { create(:collection_user, collection:, user: target) }

        it "grants nothing further" do
          expect { request }.not_to(change { collection.collection_users.count })
        end
      end
    end

    context "when signed in as a curator who manages the collection" do
      before do
        sign_in(curator)
        create(:collection_user, :manager, collection:, user: curator)
      end

      it "grants nothing" do
        expect { request }.not_to(change { collection.collection_users.count })
      end
    end
  end

  describe "PATCH /collections/:slug/people/:id" do
    subject(:request) { patch collection_person_path(collection, grant), params: { access: "editor" } }

    let(:grant) { create(:collection_user, collection:, user: curator) }

    before { sign_in(admin) }

    it "changes the grant" do
      request
      expect(grant.reload.access).to eq("editor")
    end
  end

  describe "DELETE /collections/:slug/people/:id" do
    subject(:request) { delete collection_person_path(collection, grant) }

    let!(:grant) { create(:collection_user, collection:, user: curator) }

    before { sign_in(admin) }

    it "revokes access" do
      expect { request }.to change { collection.collection_users.count }.by(-1)
    end

    it "stays on the people page" do
      request
      expect(response).to redirect_to(collection_people_path(collection))
    end
  end

  describe "the collections list" do
    subject(:request) { get collections_path }

    before { sign_in(curator) }

    context "when the curator holds no grant" do
      before { collection }

      it "does not show the collection" do
        request
        expect(response.body).not_to include("Handbook")
      end
    end

    context "when the curator holds an editor grant" do
      before { create(:collection_user, :editor, collection:, user: curator) }

      it "shows the collection" do
        request
        expect(response.body).to include("Handbook")
      end
    end

    context "when the curator's group holds an editor grant" do
      before do
        group = create(:group)
        group.users << curator
        create(:collection_group, :editor, collection:, group:)
      end

      it "shows the collection" do
        request
        expect(response.body).to include("Handbook")
      end
    end
  end

  describe "creating a collection" do
    subject(:request) { post collections_path, params: { collection: { name: "New Shelf" } } }

    before { sign_in(curator) }

    # Otherwise a curator immediately can't build the thing they just made.
    it "makes the creator its manager" do
      request
      expect(curator.grant_on(Collection.find_by(name: "New Shelf"))).to eq(:manager)
    end
  end
end
