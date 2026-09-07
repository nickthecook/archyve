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
        { email_address: "new@example.com", password: "a-long-enough-password", role: "operator" }
      end

      it "creates the account" do
        expect { request }.to change(User, :count).by(1)
      end

      it "gives it the chosen role" do
        request
        expect(User.find_by(email_address: "new@example.com").role).to eq("operator")
      end
    end

    context "with an email that is already taken" do
      let(:attributes) { { email_address: admin.email_address, password: "a-long-enough-password" } }

      it "creates nothing" do
        expect { request }.not_to change(User, :count)
      end
    end
  end

  describe "PATCH /settings/users/:id" do
    subject(:request) { patch settings_user_path(target), params: { user: attributes } }

    let(:target) { create(:user, email_address: "someone@example.com") }

    context "when the role changes" do
      let(:attributes) { { role: "operator" } }

      it "saves the new role" do
        request
        expect(target.reload.role).to eq("operator")
      end
    end

    # An admin changing someone's role shouldn't have to reset their password.
    context "when the password field is left blank" do
      let(:attributes) { { role: "operator", password: "" } }

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
      let(:attributes) { { role: "operator" } }

      it "refuses" do
        request
        expect(target.reload.role).to eq("admin")
      end
    end

    context "when an admin is demoted while another admin remains" do
      let(:target) { admin }
      let(:attributes) { { role: "operator" } }

      before { create(:user, :admin) }

      it "allows it" do
        request
        expect(target.reload.role).to eq("operator")
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
