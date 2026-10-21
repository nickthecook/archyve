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

      it "records when they signed in" do
        request
        expect(user.reload.last_signed_in_at).to be_within(1.second).of(Time.current)
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

RSpec.describe "Sessions and SSO", :unauthenticated, type: :request do
  describe "the sign-in page" do
    context "when SSO is not configured" do
      it "offers only the password form" do
        get new_session_path

        expect(response.body).not_to include("Sign in with SSO")
        expect(response.body).to include("Password")
      end
    end

    context "when SSO is configured" do
      before { configure_sso }

      it "makes SSO the way in and keeps the password form reachable" do
        get new_session_path

        expect(response.body).to include("Sign in with SSO")
        expect(response.body).to include("Use a password")
      end

      # The response is a redirect to another origin. Turbo would follow it with
      # fetch and CORS would refuse; it has to be a top-level navigation.
      it "takes the SSO form out of Turbo's hands" do
        get new_session_path

        expect(response.body).to match(%r{<form[^>]*action="/sso"[^>]*data-turbo="false"})
      end

      # The only way to see a flash here is to have just tried a password, so
      # collapsing the form the user was using would be perverse.
      it "opens the password disclosure when there is an alert to explain" do
        post session_path, params: { email_address: "nobody@example.com", password: "wrong" }
        follow_redirect!

        expect(response.body).to match(/<details[^>]*\sopen/)
      end
    end
  end

  describe "an SSO user at the password form" do
    let!(:user) { create(:user, :sso, email_address: "sso@example.com") }

    # They have no password digest at all, so this must fail cleanly rather
    # than raise — and it is what stops the group check being bypassable.
    it "cannot sign in" do
      post session_path, params: { email_address: user.email_address, password: "anything" }

      expect(response).to redirect_to(new_session_path)
      expect(user.sessions).to be_empty
    end
  end

  describe "signing out" do
    before { configure_sso }

    context "with an SSO session" do
      it "ends the session at the provider too" do
        stub_sso_http
        sign_in_with_sso

        delete session_path

        expect(response.location).to start_with("https://keycloak.test/realms/home/protocol/openid-connect/logout")
        query = Rack::Utils.parse_query(URI.parse(response.location).query)
        expect(query["post_logout_redirect_uri"]).to eq(new_session_url)
        expect(query["id_token_hint"]).to be_present
      end

      # Same cross-origin redirect problem as the sign-in button.
      it "takes the sign-out form out of Turbo's hands" do
        stub_sso_http
        sign_in_with_sso

        # A contained page, so Views::Chrome renders and with it the account menu.
        get account_path

        expect(response.body).to match(%r{<form[^>]*action="/session"[^>]*data-turbo="false"})
      end

      it "still destroys the local session" do
        stub_sso_http
        sign_in_with_sso

        expect { delete session_path }.to change(Session, :count).by(-1)
      end
    end

    context "with a password session" do
      it "signs out locally" do
        user = create(:user)
        post session_path, params: { email_address: user.email_address, password: AuthenticationHelpers::PASSWORD }

        delete session_path

        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "an expired session" do
    it "stops being accepted" do
      user = create(:user, :operator)
      post session_path, params: { email_address: user.email_address, password: AuthenticationHelpers::PASSWORD }

      user.sessions.sole.update!(created_at: (Session::LIFETIME + 1.minute).ago)

      get collections_path
      expect(response).to redirect_to(new_session_path)
    end
  end
end
