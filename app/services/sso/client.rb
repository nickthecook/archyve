require "base64"
require "digest"
require "securerandom"

# The OIDC authorization-code flow, hand-rolled against one known provider.
#
# The ID token's signature is deliberately not verified. OIDC Core 3.1.3.7 item
# 6 allows that when the token comes straight from the token endpoint over TLS
# with client authentication, which is exactly this exchange — so there is no
# JWKS to fetch, cache, or rotate. The claims are still validated below.
class Sso::Client
  # Short on purpose: someone is watching a redirect finish. The shared stack's
  # 120s default would leave them staring at a blank tab.
  TIMEOUT = 10

  class ExchangeFailed < Sso::Error; end

  class << self
    def code_verifier = SecureRandom.urlsafe_base64(64)

    def code_challenge(verifier)
      Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    end
  end

  def discover
    # The whole URL as the base, with an empty path: an issuer can carry a path
    # of its own (Keycloak's realms live under one), and a leading-slash path
    # would replace it rather than extend it.
    parse(connection("#{Sso.issuer}#{Sso::DISCOVERY_PATH}").get(""))
  rescue Faraday::Error => e
    raise Sso::Error, "Couldn't read the SSO discovery document: #{describe(e)}"
  end

  def authorization_url(redirect_uri:, state:, nonce:, code_challenge:)
    endpoint = Sso.authorization_endpoint
    query = {
      response_type: "code",
      client_id: Sso.client_id,
      redirect_uri:,
      scope: "openid email profile",
      state:,
      nonce:,
      code_challenge:,
      code_challenge_method: "S256"
    }

    separator = endpoint.include?("?") ? "&" : "?"
    "#{endpoint}#{separator}#{query.to_query}"
  end

  # Returns the ID token's claims, having checked them, plus the raw token so a
  # later sign-out can hand it back to Keycloak as id_token_hint.
  def exchange(code:, redirect_uri:, code_verifier:, nonce:)
    body = post_token(code:, redirect_uri:, code_verifier:)
    id_token = body["id_token"].presence or raise ExchangeFailed, "SSO returned no ID token."

    [claims_from(id_token, nonce:), id_token]
  end

  private

  def post_token(code:, redirect_uri:, code_verifier:)
    response = connection(Sso.token_endpoint).post("") do |request|
      request.headers["Authorization"] = basic_auth
      request.body = {
        grant_type: "authorization_code", code:, redirect_uri:, code_verifier:
      }
    end

    parse(response)
  rescue Faraday::Error => e
    raise ExchangeFailed, "SSO rejected the sign-in: #{describe(e)}"
  end

  def claims_from(id_token, nonce:)
    claims = decode_payload(id_token)

    verify!(claims["iss"] == Sso.issuer, "token came from #{claims['iss'].inspect}")
    verify!(Array(claims["aud"]).include?(Sso.client_id), "token wasn't issued for Archyve")
    verify!(claims["exp"].to_i > Time.current.to_i, "token has expired")
    verify!(claims["nonce"] == nonce, "token replays an older sign-in")

    claims
  end

  def decode_payload(id_token)
    payload = id_token.split(".")[1] or raise ExchangeFailed, "SSO returned a malformed ID token."

    JSON.parse(Base64.urlsafe_decode64(payload.ljust((payload.length + 3) & ~3, "=")))
  rescue ArgumentError, JSON::ParserError
    raise ExchangeFailed, "SSO returned an unreadable ID token."
  end

  def verify!(condition, complaint)
    raise ExchangeFailed, "Couldn't trust the SSO response: #{complaint}." unless condition
  end

  def basic_auth
    "Basic #{Base64.strict_encode64("#{Sso.client_id}:#{Sso.client_secret}")}"
  end

  def connection(base_url) = Http.connection(base_url, timeout: TIMEOUT)

  def parse(response)
    body = response.body
    body.is_a?(Hash) ? body : JSON.parse(body.to_s)
  rescue JSON::ParserError
    raise Sso::Error, "SSO returned something that wasn't JSON."
  end

  # Faraday's :raise_error middleware keeps the body on the exception, and for
  # OIDC that body is the only place the actual reason lives.
  def describe(error)
    body = error.respond_to?(:response) && error.response&.dig(:body)
    parsed = body.is_a?(String) ? (JSON.parse(body) rescue nil) : body
    return error.message unless parsed.is_a?(Hash)

    [parsed["error"], parsed["error_description"]].compact.join(" — ").presence || error.message
  end
end
