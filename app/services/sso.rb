# Single sign-on against an OIDC provider (Keycloak in practice).
#
# Settings come from the environment rather than the database, unlike
# InferenceServer and Endpoint: this one decides who may sign in at all, so it
# has to be readable before anyone has. See docs/architecture.md.
module Sso
  # Every setting is required, the group included. "SSO is configured" can then
  # never mean "SSO is configured but ungated" — there is no half-set state that
  # quietly lets the whole realm in.
  SETTINGS = %w[
    ARCHYVE_SSO_ISSUER
    ARCHYVE_SSO_CLIENT_ID
    ARCHYVE_SSO_CLIENT_SECRET
    ARCHYVE_SSO_GROUP
  ].freeze

  DISCOVERY_PATH = "/.well-known/openid-configuration"
  DISCOVERY_CACHE_TTL = 1.hour

  class Error < StandardError; end
  class NotConfigured < Error; end

  class << self
    def configured? = SETTINGS.all? { |name| ENV[name].present? }

    def issuer = ENV.fetch("ARCHYVE_SSO_ISSUER").chomp("/")
    def client_id = ENV.fetch("ARCHYVE_SSO_CLIENT_ID")
    def client_secret = ENV.fetch("ARCHYVE_SSO_CLIENT_SECRET")
    def required_group = ENV.fetch("ARCHYVE_SSO_GROUP")

    def authorization_endpoint = discover.fetch("authorization_endpoint")
    def token_endpoint = discover.fetch("token_endpoint")
    def end_session_endpoint = discover["end_session_endpoint"]

    def discover
      raise NotConfigured, "SSO is not configured" unless configured?

      Rails.cache.fetch("sso/discovery/#{issuer}", expires_in: DISCOVERY_CACHE_TTL) do
        Client.new.discover
      end
    end
  end
end
