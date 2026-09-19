require "rails_helper"

RSpec.describe "Accounts", :unauthenticated, type: :request do
  let(:user) { create(:user) }
  let(:password) { AuthenticationHelpers::PASSWORD }

  before { sign_in(user) }

  describe "GET /account" do
    subject(:request) { get account_path }

    it "shows the signed-in address" do
      request
      expect(response.body).to include(user.email_address)
    end
  end

  describe "PATCH /account" do
    subject(:request) do
      patch account_path,
        params: { current_password:, password: new_password, password_confirmation: confirmation }
    end

    let(:new_password) { "a-brand-new-password" }
    let(:confirmation) { new_password }

    context "when the current password is right and the new one is confirmed" do
      let(:current_password) { password }

      it "changes the password" do
        request
        expect(user.reload.authenticate(new_password)).to be_truthy
      end

      it "says so" do
        request
        expect(flash[:notice]).to include("Password changed")
      end

      # Changing a password is how you lock out whoever you think has it.
      context "when the user is also signed in elsewhere" do
        let!(:elsewhere) { user.sessions.create! }

        it "ends the other session" do
          request
          expect(Session.exists?(elsewhere.id)).to be(false)
        end

        it "keeps the session doing the changing" do
          expect { request }.to change { user.sessions.count }.by(-1)
        end
      end
    end

    context "when the current password is wrong" do
      let(:current_password) { "not-the-password" }

      it "refuses" do
        request
        expect(user.reload.authenticate(new_password)).to be(false)
      end

      it "says why" do
        request
        expect(flash[:alert]).to eq("That isn't your current password.")
      end
    end

    context "when the confirmation doesn't match" do
      let(:current_password) { password }
      let(:confirmation) { "something-else" }

      it "refuses" do
        request
        expect(user.reload.authenticate(new_password)).to be(false)
      end
    end
  end
end

RSpec.describe "Accounts and SSO", :unauthenticated, type: :request do
  let(:user) { create(:user, :sso) }

  before { sign_in_as_sso_user(user) }

  it "says where the password lives instead of offering a form" do
    get account_path

    expect(response.body).to include("managed there rather than in Archyve")
    expect(response.body).not_to include("Change password")
  end

  # Hiding the form is not enforcement. Setting a password would be a way back
  # in through /session/new after the IdP revoked their access.
  it "refuses a password change" do
    patch account_path, params: { current_password: "x", password: "a-new-password", password_confirmation: "a-new-password" }

    expect(response).to redirect_to(account_path)
    expect(user.reload.password_digest).to be_nil
  end
end
