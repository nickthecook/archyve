require "rails_helper"

RSpec.describe "Source groups", :unauthenticated, type: :request do
  let(:source) { create(:source, name: "Reference library") }
  let(:group) { create(:group, name: "Records") }

  describe "POST /sources/:id/groups" do
    subject(:request) { post source_groups_path(source), params: { group_id: group.id, access: "accessor" } }

    context "when signed in as an admin" do
      before { sign_in(create(:user, :admin)) }

      it "grants the group access" do
        expect { request }.to change { source.source_groups.count }.by(1)
      end

      it "returns to the people page" do
        request
        expect(response).to redirect_to(source_people_path(source))
      end
    end

    context "when signed in as a curator who owns the source" do
      let(:source) { create(:source, user: curator) }
      let(:curator) { create(:user, :curator) }

      before { sign_in(curator) }

      it "grants nothing" do
        expect { request }.not_to(change { source.source_groups.count })
      end
    end
  end

  describe "PATCH /sources/:id/groups/:id" do
    subject(:request) { patch source_group_path(source, grant), params: { access: "editor" } }

    let(:grant) { create(:source_group, source:, group:) }

    before { sign_in(create(:user, :admin)) }

    it "changes the grant" do
      request
      expect(grant.reload.access).to eq("editor")
    end
  end

  describe "DELETE /sources/:id/groups/:id" do
    subject(:request) { delete source_group_path(source, grant) }

    let!(:grant) { create(:source_group, source:, group:) }

    before { sign_in(create(:user, :admin)) }

    it "revokes the group's access" do
      expect { request }.to change { source.source_groups.count }.by(-1)
    end
  end
end
