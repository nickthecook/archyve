require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let(:password) { AuthenticationHelpers::PASSWORD }

  describe "GET /session/new", :unauthenticated do
    subject(:request) { get new_session_path }

    it "renders the sign-in form" do
      request
      expect(response.body).to include("Sign in")
    end

    it "does not render the nav, which goes nowhere signed out" do
      request
      expect(response.body).not_to include("Collections")
    end
  end

  describe "POST /session", :unauthenticated do
    subject(:request) { post session_path, params: { email_address:, password: submitted_password } }

    let!(:user) { create(:user, email_address: "nick@example.com") }

    context "when the credentials match" do
      let(:email_address) { "nick@example.com" }
      let(:submitted_password) { password }

      it "redirects into the app" do
        request
        expect(response).to redirect_to(root_url)
      end

      it "starts a session for the user" do
        expect { request }.to change { user.sessions.count }.by(1)
      end
    end

    # Normalization has to apply on the way in as well as on the way out, or an
    # account is unreachable from the casing its owner actually types.
    context "when the email address differs only by case" do
      let(:email_address) { "Nick@Example.com" }
      let(:submitted_password) { password }

      it "starts a session for the user" do
        expect { request }.to change { user.sessions.count }.by(1)
      end
    end

    context "when the password is wrong" do
      let(:email_address) { "nick@example.com" }
      let(:submitted_password) { "not-the-password" }

      it "returns to the sign-in page" do
        request
        expect(response).to redirect_to(new_session_path)
      end

      it "starts no session" do
        expect { request }.not_to(change { Session.count })
      end
    end

    context "when no user has that email address" do
      let(:email_address) { "nobody@example.com" }
      let(:submitted_password) { password }

      it "returns to the sign-in page" do
        request
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "DELETE /session" do
    subject(:request) { delete session_path }

    it "redirects to the sign-in page" do
      request
      expect(response).to redirect_to(new_session_path)
    end

    it "discards the session row" do
      expect { request }.to change { Session.count }.by(-1)
    end

    context "when a protected page is requested afterwards" do
      before { request }

      it "is no longer reachable" do
        get collections_path
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "requesting a protected page while signed out", :unauthenticated do
    subject(:request) { get collections_path }

    it "redirects to the sign-in page" do
      request
      expect(response).to redirect_to(new_session_path)
    end

    # Being bounced to sign-in shouldn't cost you the page you asked for.
    context "when the user then signs in" do
      let(:user) { create(:user) }

      before do
        request
        post session_path, params: { email_address: user.email_address, password: }
      end

      it "returns to the page originally requested" do
        expect(response).to redirect_to(collections_url)
      end
    end
  end

  describe "the health check", :unauthenticated do
    subject(:request) { get rails_health_check_path }

    it "stays reachable signed out, so uptime monitors keep working" do
      request
      expect(response).to have_http_status(:ok)
    end
  end
end
