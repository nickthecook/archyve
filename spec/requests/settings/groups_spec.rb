require "rails_helper"

RSpec.describe "Settings::Groups", :unauthenticated, type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in(admin) }

  describe "the People page" do
    subject(:request) { get settings_users_path }

    let!(:group) { create(:group, name: "Human Resources") }

    it "lists groups" do
      request
      expect(response.body).to include(settings_group_path(group))
    end
  end

  describe "GET /settings/groups/:id as a curator" do
    subject(:request) { get settings_group_path(create(:group)) }

    before { sign_in(create(:user, :curator)) }

    it "is refused" do
      request
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /settings/groups" do
    subject(:request) { post settings_groups_path, params: { group: { name: } } }

    context "with a name" do
      let(:name) { "Finance" }

      it "creates the group" do
        expect { request }.to change(Group, :count).by(1)
      end

      it "goes to the new group" do
        request
        expect(response).to redirect_to(settings_group_path(Group.find_by!(name: "Finance")))
      end
    end

    context "with a name already taken" do
      let(:name) { "Finance" }

      before { create(:group, name: "Finance") }

      it "creates nothing" do
        expect { request }.not_to change(Group, :count)
      end

      it "says why, back on the People page" do
        request
        expect(response.body).to include("Name has already been taken")
      end
    end
  end

  describe "GET /settings/groups/:id" do
    subject(:request) { get settings_group_path(group) }

    let(:group) { create(:group, name: "Finance") }

    before do
      group.users << create(:user, email_address: "member@example.com")
      create(:collection_group, :editor, group:, collection: create(:collection, name: "Ledgers"))
    end

    it "lists its members" do
      request
      expect(response.body).to include("member@example.com")
    end

    it "lists what it has been given" do
      request
      expect(response.body).to include("Ledgers")
    end
  end

  describe "PATCH /settings/groups/:id" do
    subject(:request) { patch settings_group_path(group), params: { group: { name: "Accounts" } } }

    let(:group) { create(:group, name: "Finance") }

    it "renames it" do
      request
      expect(group.reload.name).to eq("Accounts")
    end
  end

  describe "DELETE /settings/groups/:id" do
    subject(:request) { delete settings_group_path(group) }

    let!(:group) { create(:group) }
    let(:collection) { create(:collection) }
    let(:member) { create(:user) }

    before do
      group.users << member
      create(:collection_group, group:, collection:)
    end

    it "deletes it" do
      expect { request }.to change(Group, :count).by(-1)
    end

    it "returns to the People page" do
      request
      expect(response).to redirect_to(settings_users_path)
    end

    it "takes away the access it gave" do
      request
      expect(member.grant_on(collection)).to be_nil
    end

    it "keeps the members' accounts" do
      expect { request }.not_to change(User, :count)
    end
  end

  describe "POST /settings/groups/:id/members" do
    subject(:request) { post settings_group_members_path(group), params: { user_id: user.id } }

    let(:group) { create(:group) }
    let(:user) { create(:user) }

    it "adds them" do
      expect { request }.to change { group.users.count }.by(1)
    end

    context "when they are already a member" do
      before { group.users << user }

      it "adds nothing" do
        expect { request }.not_to(change { group.users.count })
      end
    end
  end

  describe "DELETE /settings/groups/:id/members/:id" do
    subject(:request) { delete settings_group_member_path(group, membership) }

    let(:group) { create(:group) }
    let!(:membership) { create(:group_user, group:) }

    it "removes them" do
      expect { request }.to change { group.users.count }.by(-1)
    end
  end
end
