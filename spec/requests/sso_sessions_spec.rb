require "rails_helper"

RSpec.describe "SSO sign-in", :unauthenticated, type: :request do
  before do
    configure_sso
    stub_sso_http
  end

  describe "starting the flow" do
    it "redirects to the provider with PKCE and a nonce" do
      post sso_sign_in_path

      expect(response).to redirect_to(%r{\Ahttps://keycloak\.test/realms/home/protocol/openid-connect/auth\?})

      query = Rack::Utils.parse_query(URI.parse(response.location).query)
      expect(query).to include(
        "response_type" => "code",
        "client_id" => SsoHelpers::CLIENT_ID,
        "code_challenge_method" => "S256",
        "redirect_uri" => sso_callback_url
      )
      expect(query["scope"].split).to include("openid", "email")
      expect(query["code_challenge"]).to be_present
      expect(query["state"]).to eq(session_state)
      expect(query["nonce"]).to eq(session_nonce)
    end

    # The verifier must never leave the server; only its hash goes to Keycloak.
    it "keeps the code verifier out of the redirect" do
      post sso_sign_in_path

      expect(response.location).not_to include(request.session[:sso_code_verifier])
    end
  end

  describe "a member of the group signing in" do
    context "when they have never signed in before" do
      it "provisions them as a plain user with no grants" do
        expect { sign_in_with_sso(sub: "new-person", email: "new@example.com") }
          .to change(User, :count).by(1)

        user = User.find_by(email_address: "new@example.com")
        expect(user).to have_attributes(
          role: "user", sso_subject: "new-person", sso_issuer: SsoHelpers::ISSUER
        )
        expect(CollectionUser.where(user:)).to be_empty
        expect(SourceUser.where(user:)).to be_empty
        expect(response).to redirect_to(root_url)
      end

      it "records the session as an SSO one" do
        sign_in_with_sso

        expect(User.last.sessions.sole.sso_id_token).to be_present
      end
    end

    context "when an Archyve account already has that email" do
      let!(:existing) { create(:user, :admin, email_address: "admin@archyve.local") }

      it "links to it rather than creating a second account" do
        expect { sign_in_with_sso(email: "admin@archyve.local", sub: "admin-uuid") }
          .not_to change(User, :count)

        expect(existing.reload).to have_attributes(sso_subject: "admin-uuid", role: "admin")
      end

      # The break-glass account has to keep working when Keycloak is down, so
      # linking must not cost it its password.
      it "leaves their password intact" do
        sign_in_with_sso(email: "admin@archyve.local", sub: "admin-uuid")

        expect(existing.reload.authenticate(AuthenticationHelpers::PASSWORD)).to be_truthy
      end

      context "when the provider hasn't verified the email" do
        # Inheriting an existing account — the break-glass admin's, say — should
        # cost more than setting an attribute at the IdP.
        it "refuses to link, and says so rather than erroring" do
          expect { sign_in_with_sso(email: "admin@archyve.local", email_verified: false) }
            .not_to change(User, :count)

          expect(existing.reload.sso_subject).to be_nil
          expect(response).to redirect_to(new_session_path)
          expect(flash[:alert]).to match(/already uses that email/i)
        end
      end
    end

    context "when they have signed in before" do
      let!(:existing) { create(:user, :sso, sso_subject: "stable-uuid", email_address: "old@example.com") }

      # Email is what changes; sub is what doesn't. Matching on sub is what
      # stops a renamed user getting a second, empty account.
      it "matches on sub even though their email changed" do
        expect { sign_in_with_sso(sub: "stable-uuid", email: "new@example.com") }
          .not_to change(User, :count)

        expect(existing.reload.email_address).to eq("new@example.com")
      end
    end
  end

  describe "someone outside the group" do
    it "is refused" do
      expect { sign_in_with_sso(groups: ["/other-app"]) }.not_to change(User, :count)

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to match(/doesn't have access/i)
    end

    # Revoking in Keycloak has to reach a browser that is already signed in.
    it "loses any session they already had" do
      user = create(:user, :sso, sso_subject: "revoked-uuid")
      session = user.sessions.create!(sso_id_token: "old-token")

      sign_in_with_sso(sub: "revoked-uuid", groups: [])

      expect(Session.where(id: session.id)).to be_empty
    end

    it "loses their API keys, which never check back with Keycloak" do
      user = create(:user, :sso, sso_subject: "revoked-uuid")
      create(:api_key, user:)

      sign_in_with_sso(sub: "revoked-uuid", groups: [])

      expect(user.api_keys.reload).to be_empty
    end

    it "has no claim on a group it wasn't given" do
      expect { sign_in_with_sso(groups: nil) }.not_to change(User, :count)
    end
  end

  describe "a callback that doesn't match the browser that started it" do
    it "refuses a mismatched state" do
      post sso_sign_in_path
      stub_token_exchange(nonce: session_nonce)

      expect { get sso_callback_path, params: { code: "c", state: "not-the-state" } }
        .not_to change(User, :count)

      expect(flash[:alert]).to match(/didn't match this browser/i)
    end

    it "refuses when there is no state at all" do
      get sso_callback_path, params: { code: "c", state: "anything" }

      expect(flash[:alert]).to be_present
      expect(User.count).to be_zero
    end

    # A replayed token from an older flow carries the wrong nonce.
    it "refuses a mismatched nonce" do
      post sso_sign_in_path
      stub_token_exchange(nonce: "a-different-nonce")

      expect { get sso_callback_path, params: { code: "c", state: session_state } }
        .not_to change(User, :count)

      expect(flash[:alert]).to match(/replays an older sign-in/i)
    end
  end

  describe "when the provider rejects the exchange" do
    it "reports it rather than erroring" do
      post sso_sign_in_path
      stub_token_error(description: "Code not valid")

      get sso_callback_path, params: { code: "stale", state: session_state }

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to include("Code not valid")
    end
  end

  describe "when the user cancels at the provider" do
    it "sends them back without an error page" do
      post sso_sign_in_path

      get sso_callback_path, params: { error: "access_denied", state: session_state }

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to match(/cancelled/i)
    end
  end

  describe "where they land afterwards" do
    it "returns them to the page that bounced them" do
      get collections_path
      expect(response).to redirect_to(new_session_path)

      sign_in_with_sso
      expect(response).to redirect_to(collections_url)
    end
  end

  describe "when SSO is not configured" do
    before { SsoHelpers::SETTINGS.each_key { |name| ENV.delete(name) } }

    # Hiding the button is not access control; the route refuses on its own.
    it "refuses to start a flow" do
      post sso_sign_in_path

      expect(response).to redirect_to(new_session_path)
    end

    it "refuses a callback" do
      get sso_callback_path, params: { code: "c", state: "s" }

      expect(response).to redirect_to(new_session_path)
    end
  end
end
