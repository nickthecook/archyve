require "rails_helper"

RSpec.describe "Collection people", :unauthenticated, type: :request do
  let(:collection) { create(:collection, name: "Handbook") }
  let(:curator) { create(:user, :curator) }

  describe "GET /collections/:slug/people" do
    subject(:request) { get collection_people_path(collection) }

    context "when the signed-in curator administers the collection" do
      before do
        sign_in(curator)
        create(:collection_user, :admin, collection:, user: curator)
      end

      it "renders" do
        request
        expect(response).to have_http_status(:ok)
      end

      it "says which kind of thing it is managing" do
        request
        expect(response.body).to include("Collection")
      end
    end

    # Filing documents into a collection is not the same as handing out access.
    context "when the signed-in curator only files documents into it" do
      before do
        sign_in(curator)
        create(:collection_user, :curator, collection:, user: curator)
      end

      it "is not found" do
        request
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in as a system admin with no grant" do
      before { sign_in(create(:user, :admin)) }

      it "renders, because admins reach every collection" do
        request
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /collections/:slug/people" do
    subject(:request) { post collection_people_path(collection), params: { user_id: target.id, role: "visitor" } }

    let(:target) { create(:user) }

    before do
      sign_in(curator)
      create(:collection_user, :admin, collection:, user: curator)
    end

    it "grants access" do
      expect { request }.to change { collection.collection_users.count }.by(1)
    end

    # A grant to a system admin is a no-op — they reach every collection
    # already — and it was that no-op that sorted first in the person list.
    it "does not offer system admins as candidates" do
      admin = create(:user, :admin, email_address: "boss@example.com")
      get collection_people_path(collection)
      expect(response.body).not_to include(admin.email_address)
    end

    it "requires a person to be chosen rather than defaulting to one" do
      target # the form only renders when there is somebody to add
      get collection_people_path(collection)
      expect(response.body).to include("Choose someone")
    end

    context "when they already have a grant" do
      before { create(:collection_user, collection:, user: target) }

      it "grants nothing further" do
        expect { request }.not_to(change { collection.collection_users.count })
      end
    end
  end

  describe "DELETE /collections/:slug/people/:id" do
    subject(:request) { delete collection_person_path(collection, grant) }

    before do
      sign_in(curator)
      create(:collection_user, :admin, collection:, user: curator)
    end

    context "with someone else's grant" do
      let!(:grant) { create(:collection_user, collection:, user: create(:user)) }

      it "revokes access" do
        expect { request }.to change { collection.collection_users.count }.by(-1)
      end

      it "stays on the people page" do
        request
        expect(response).to redirect_to(collection_people_path(collection))
      end
    end

    # Revoking your own access is allowed — a system admin can restore it — but
    # the page you were on is one you can no longer reach, so the redirect can't
    # go back to it.
    context "when revoking your own access" do
      let(:grant) { collection.collection_users.find_by!(user: curator) }

      it "still revokes it" do
        expect { request }.to change { collection.collection_users.count }.by(-1)
      end

      it "redirects to the collections list" do
        request
        expect(response).to redirect_to(collections_path)
      end

      it "lands somewhere still reachable, rather than 404ing on the way out" do
        request
        follow_redirect!
        expect(response).to have_http_status(:ok)
      end
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

    context "when the curator holds a grant" do
      before { create(:collection_user, collection:, user: curator) }

      it "shows the collection" do
        request
        expect(response.body).to include("Handbook")
      end
    end
  end

  describe "creating a collection" do
    subject(:request) { post collections_path, params: { collection: { name: "New Shelf" } } }

    before { sign_in(curator) }

    # Otherwise a curator immediately can't manage the thing they just made.
    it "makes the creator its admin" do
      request
      expect(curator.role_on(Collection.find_by(name: "New Shelf"))).to eq(:admin)
    end
  end
end
