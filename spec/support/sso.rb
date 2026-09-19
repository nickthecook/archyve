require "base64"

# Stands an OIDC provider up in memory: the environment SSO reads its settings
# from, plus Faraday stubs at the Http.connection seam every other outbound call
# in this suite is stubbed at. Nothing here reaches the network — see
# spec/support/no_network.rb, which fails the example if anything tries.
module SsoHelpers
  ISSUER = "https://keycloak.test/realms/home".freeze
  CLIENT_ID = "archyve".freeze
  GROUP = "/archyve-users".freeze

  DISCOVERY_PATH = "/realms/home/.well-known/openid-configuration".freeze
  AUTHORIZE_PATH = "/realms/home/protocol/openid-connect/auth".freeze
  TOKEN_PATH = "/realms/home/protocol/openid-connect/token".freeze
  LOGOUT_PATH = "/realms/home/protocol/openid-connect/logout".freeze

  SETTINGS = {
    "ARCHYVE_SSO_ISSUER" => ISSUER,
    "ARCHYVE_SSO_CLIENT_ID" => CLIENT_ID,
    "ARCHYVE_SSO_CLIENT_SECRET" => "a-client-secret",
    "ARCHYVE_SSO_GROUP" => GROUP
  }.freeze

  def configure_sso
    SETTINGS.each { |name, value| ENV[name] = value }
  end

  def sso_stubs = @sso_stubs ||= Faraday::Adapter::Test::Stubs.new

  # One connection per base_url, so discovery and the token exchange are matched
  # by their real paths rather than by call order.
  def stub_sso_http
    allow(Http).to receive(:connection) do |base_url, **|
      Faraday.new(url: base_url) do |f|
        f.request :url_encoded
        f.response :raise_error
        f.adapter :test, sso_stubs
      end
    end

    stub_discovery
  end

  def stub_discovery
    sso_stubs.get(DISCOVERY_PATH) do
      [200, { "Content-Type" => "application/json" }, {
        issuer: ISSUER,
        authorization_endpoint: "#{ISSUER}/protocol/openid-connect/auth",
        token_endpoint: "#{ISSUER}/protocol/openid-connect/token",
        end_session_endpoint: "#{ISSUER}/protocol/openid-connect/logout"
      }.to_json]
    end
  end

  # The token endpoint's happy path. `claims` overrides anything in the ID token.
  def stub_token_exchange(nonce:, **claims)
    payload = {
      iss: ISSUER, aud: CLIENT_ID, sub: "keycloak-uuid-1", nonce:,
      exp: 5.minutes.from_now.to_i, email: "person@example.com",
      email_verified: true, groups: [GROUP]
    }.merge(claims)

    sso_stubs.post(TOKEN_PATH) do
      [200, { "Content-Type" => "application/json" },
       { id_token: id_token_for(payload), token_type: "Bearer" }.to_json]
    end
    payload
  end

  def stub_token_error(error: "invalid_grant", description: "Code not valid")
    sso_stubs.post(TOKEN_PATH) do
      [400, { "Content-Type" => "application/json" },
       { error:, error_description: description }.to_json]
    end
  end

  # Unsigned on purpose: the client doesn't verify the signature, because the
  # token comes straight from the token endpoint over TLS. See Sso::Client.
  def id_token_for(payload)
    segment = ->(hash) { Base64.urlsafe_encode64(hash.to_json, padding: false) }
    "#{segment.call({ alg: 'RS256' })}.#{segment.call(payload)}.signature"
  end

  # Drives the whole redirect round trip and returns the claims that were sent.
  def sign_in_with_sso(**claims)
    post sso_sign_in_path
    nonce = session_nonce
    payload = stub_token_exchange(nonce:, **claims)
    get sso_callback_path, params: { code: "an-auth-code", state: session_state }
    payload
  end

  # Signs an existing SSO user in through the real redirect round trip, the way
  # spec/support/authentication.rb signs in through the real form.
  def sign_in_as_sso_user(user)
    configure_sso
    stub_sso_http
    sign_in_with_sso(sub: user.sso_subject, email: user.email_address)
  end

  def session_state = request.session[:sso_state]
  def session_nonce = request.session[:sso_nonce]
end

RSpec.configure do |config|
  config.include SsoHelpers, type: :request
  config.include SsoHelpers, type: :model

  # SSO is off unless an example asks for it, and every example leaves the
  # environment as it found it.
  config.around do |example|
    saved = SsoHelpers::SETTINGS.keys.index_with { |name| ENV[name] }
    SsoHelpers::SETTINGS.each_key { |name| ENV.delete(name) }
    example.run
    saved.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
  end
end
