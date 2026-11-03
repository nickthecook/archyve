require "rails_helper"

RSpec.describe "Settings::Users", :unauthenticated, type: :request do
  let!(:admin) { create(:user, :admin, email_address: "admin@example.com") }

  before { sign_in(admin) }

  describe "GET /settings/users" do
    subject(:request) { get settings_users_path }

    context "when other people have accounts" do
      let!(:other) { create(:user, email_address: "someone@example.com") }

      it "lists them" do
        request
        expect(response.body).to include("someone@example.com")
      end
    end
  end

  describe "POST /settings/users" do
    subject(:request) { post settings_users_path, params: { user: attributes } }

    context "with an email, password and role" do
      let(:attributes) do
        { email_address: "new@example.com", password: "a-long-enough-password", role: "curator" }
      end

      it "creates the account" do
        expect { request }.to change(User, :count).by(1)
      end

      it "gives it the chosen role" do
        request
        expect(User.find_by(email_address: "new@example.com").role).to eq("curator")
      end
    end

    context "with an email that is already taken" do
      let(:attributes) { { email_address: admin.email_address, password: "a-long-enough-password" } }

      it "creates nothing" do
        expect { request }.not_to change(User, :count)
      end
    end
  end

  describe "GET /settings/users/:id/edit" do
    subject(:request) { get edit_settings_user_path(target) }

    let(:target) { create(:user, :curator) }

    context "when they hold grants" do
      before do
        create(:collection_user, user: target, collection: create(:collection, name: "HR Policies"))
        create(:source_user, user: target, source: create(:source, name: "Shared Drive"))
      end

      it "lists the collections" do
        request
        expect(response.body).to include("HR Policies")
      end

      it "lists the sources" do
        request
        expect(response.body).to include("Shared Drive")
      end
    end

    context "when a grant is capped by their role" do
      let(:target) { create(:user) }

      before { create(:collection_user, :manager, user: target) }

      it "says what they actually get" do
        request
        expect(response.body).to include("so: accessor")
      end
    end

    context "when they are an admin with grants" do
      let(:target) { create(:user, :admin) }

      before { create(:collection_user, :manager, user: target) }

      it "offers no revoke form" do
        request
        expect(response.body).not_to include(settings_user_collection_grant_path(target, target.collection_users.first))
      end
    end

    context "when they hold no grants" do
      it "says so" do
        request
        expect(response.body).to include("No grants")
      end
    end
  end

  describe "DELETE /settings/users/:user_id/collection_grants/:id" do
    subject(:request) { delete settings_user_collection_grant_path(target, grant) }

    let(:target) { create(:user, :curator) }
    let!(:grant) { create(:collection_user, user: target) }

    it "revokes the grant" do
      expect { request }.to change(CollectionUser, :count).by(-1)
    end

    it "returns to their page" do
      request
      expect(response).to redirect_to(edit_settings_user_path(target))
    end

    it "offers to undo it" do
      request
      follow_redirect!
      expect(response.body).to include(%(action="#{settings_user_collection_grants_path(target)}"))
    end

    context "with someone else's grant" do
      let(:grant) { create(:collection_user) }

      it "revokes nothing" do
        expect { request }.not_to change(CollectionUser, :count)
      end
    end

    # A revoke that changes nothing today would silently bite after a demotion.
    context "when they are an admin" do
      let(:target) { create(:user, :admin) }

      it "revokes nothing" do
        expect { request }.not_to change(CollectionUser, :count)
      end

      it "says why" do
        request
        expect(flash[:alert]).to include("Change their role first")
      end
    end
  end

  describe "POST /settings/users/:user_id/collection_grants" do
    subject(:request) do
      post settings_user_collection_grants_path(target), params: { subject_id: collection.id, access: "editor" }
    end

    let(:target) { create(:user, :curator) }
    let(:collection) { create(:collection) }

    it "restores the grant" do
      request
      expect(target.collection_users.find_by(collection:).access).to eq("editor")
    end

    context "when the grant already exists" do
      before { create(:collection_user, user: target, collection:) }

      it "creates nothing" do
        expect { request }.not_to change(CollectionUser, :count)
      end
    end
  end

  describe "DELETE /settings/users/:user_id/source_grants/:id" do
    subject(:request) { delete settings_user_source_grant_path(target, grant) }

    let(:target) { create(:user, :curator) }
    let!(:grant) { create(:source_user, user: target) }

    it "revokes the grant" do
      expect { request }.to change(SourceUser, :count).by(-1)
    end
  end

  describe "PATCH /settings/users/:id" do
    subject(:request) { patch settings_user_path(target), params: { user: attributes } }

    let(:target) { create(:user, email_address: "someone@example.com") }

    context "when the role changes" do
      let(:attributes) { { role: "curator" } }

      it "saves the new role" do
        request
        expect(target.reload.role).to eq("curator")
      end
    end

    # An admin changing someone's role shouldn't have to reset their password.
    context "when the password field is left blank" do
      let(:attributes) { { role: "curator", password: "" } }

      it "leaves the existing password working" do
        request
        expect(target.reload.authenticate(AuthenticationHelpers::PASSWORD)).to be_truthy
      end
    end

    context "when a new password is given" do
      let(:attributes) { { password: "a-replacement-password" } }

      it "sets it" do
        request
        expect(target.reload.authenticate("a-replacement-password")).to be_truthy
      end
    end

    context "when the only admin is demoted" do
      let(:target) { admin }
      let(:attributes) { { role: "curator" } }

      it "refuses" do
        request
        expect(target.reload.role).to eq("admin")
      end
    end

    context "when an admin is demoted while another admin remains" do
      let(:target) { admin }
      let(:attributes) { { role: "curator" } }

      before { create(:user, :admin) }

      it "allows it" do
        request
        expect(target.reload.role).to eq("curator")
      end
    end
  end

  describe "DELETE /settings/users/:id" do
    subject(:request) { delete settings_user_path(target) }

    context "with an ordinary account" do
      let!(:target) { create(:user) }

      it "removes it" do
        expect { request }.to change(User, :count).by(-1)
      end
    end

    context "with an account that holds grants" do
      let!(:target) { create(:user, :curator) }

      before do
        create(:collection_user, user: target)
        create(:source_user, user: target)
      end

      it "removes it along with its grants" do
        expect { request }.to change(CollectionUser, :count).by(-1).and change(User, :count).by(-1)
      end
    end

    # The failure this prevents: an admin removing themselves and leaving an
    # Archyve nobody can administer.
    context "with the only admin" do
      let(:target) { admin }

      it "refuses" do
        expect { request }.not_to change(User, :count)
      end

      it "says why" do
        request
        expect(flash[:alert]).to include("only admin")
      end
    end
  end
end
