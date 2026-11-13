require "rails_helper"

RSpec.describe "Collection groups", :unauthenticated, type: :request do
  let(:collection) { create(:collection, name: "Handbook") }
  let(:group) { create(:group, name: "Human Resources") }

  describe "POST /collections/:slug/groups" do
    subject(:request) { post collection_groups_path(collection), params: { group_id: group.id, access: "accessor" } }

    context "when signed in as an admin" do
      before { sign_in(create(:user, :admin)) }

      it "grants the group access" do
        expect { request }.to change { collection.collection_groups.count }.by(1)
      end

      it "returns to the people page" do
        request
        expect(response).to redirect_to(collection_people_path(collection))
      end

      context "when the group already has a grant" do
        before { create(:collection_group, collection:, group:) }

        it "grants nothing further" do
          expect { request }.not_to(change { collection.collection_groups.count })
        end
      end
    end

    context "when signed in as a curator who manages the collection" do
      before do
        curator = create(:user, :curator)
        sign_in(curator)
        create(:collection_user, :manager, collection:, user: curator)
      end

      it "grants nothing" do
        expect { request }.not_to(change { collection.collection_groups.count })
      end
    end
  end

  describe "PATCH /collections/:slug/groups/:id" do
    subject(:request) { patch collection_group_path(collection, grant), params: { access: "editor" } }

    let(:grant) { create(:collection_group, collection:, group:) }

    before { sign_in(create(:user, :admin)) }

    it "changes the grant" do
      request
      expect(grant.reload.access).to eq("editor")
    end
  end

  describe "DELETE /collections/:slug/groups/:id" do
    subject(:request) { delete collection_group_path(collection, grant) }

    let!(:grant) { create(:collection_group, collection:, group:) }

    before { sign_in(create(:user, :admin)) }

    it "revokes the group's access" do
      expect { request }.to change { collection.collection_groups.count }.by(-1)
    end
  end
end
