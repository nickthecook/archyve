module Endpoints
  # One SharePoint Online site, reached through Microsoft Graph as an Entra app
  # registration. App-only: Graph serves whatever the registration's application
  # permissions grant, so this row is an identity in the same sense as
  # Endpoints::Bookstack.
  class Sharepoint < Endpoint
    ACCESS_TIMEOUT = 15
    LOGIN_URL = "https://login.microsoftonline.com".freeze
    GRAPH_URL = "https://graph.microsoft.com/v1.0/".freeze
    GRAPH_SCOPE = "https://graph.microsoft.com/.default".freeze
    TOKEN_EXPIRY_MARGIN = 5.minutes
    SITE_PATH = %r{\A/(sites|teams)/[^/]+\z}

    Error = Class.new(StandardError)

    TOKENS = Concurrent::Map.new

    store_accessor :config, :client_id, :tenant_id
    credential :client_secret

    validates :base_url, presence: true
    validates :client_id, presence: true
    validates :client_secret, presence: true
    validate :base_url_must_be_a_sharepoint_site, if: -> { base_url.present? }

    def self.permitted_keys = super + [:client_id, :client_secret, :tenant_id]
    def self.form_component = Views::Settings::Endpoints::Forms::Sharepoint

    def self.type_label = "SharePoint"

    def self.description
      "A SharePoint Online site, read through Microsoft Graph. Needs an Entra app registration's client id and secret."
    end

    # A tenant's SharePoint host is named after its initial onmicrosoft.com
    # domain, and Entra accepts that domain wherever it accepts the tenant's id.
    def tenant = tenant_id.presence || "#{host.split('.').first}.onmicrosoft.com"

    # Relative, so Faraday appends it to GRAPH_URL's /v1.0 rather than replacing it.
    # A site addressed by path needs a closing colon before anything beneath it.
    def site_path(child = nil)
      path = URI.parse(base_url).path
      site = path.present? ? "sites/#{host}:#{path}" : "sites/#{host}"
      return site if child.nil?

      path.present? ? "#{site}:/#{child}" : "#{site}/#{child}"
    end

    def client(timeout: DEFAULT_TIMEOUT, raise_errors: true)
      Http.connection(GRAPH_URL, timeout: timeout, raise_errors: raise_errors).tap do |connection|
        auth_headers.each { |header, value| connection.headers[header] = value }
      end
    end

    def auth_headers = { "Authorization" => "Bearer #{access_token}" }

    def graph_get(path, params = {}, timeout: DEFAULT_TIMEOUT)
      response = client(timeout:, raise_errors: false).get(path, params)
      return parse(response) if response.success?

      raise Error, graph_error(response)
    end

    def graph(timeout: DEFAULT_TIMEOUT) = ::Sharepoint::Graph.new(self, timeout:)

    def access!
      response = client(timeout: ACCESS_TIMEOUT, raise_errors: false).get(site_path)
      return if response.success?

      raise Error, response.status == 404 ? "no site at #{base_url} that this app can see" : graph_error(response)
    end

    private

    # Per process rather than in Rails.cache, which would put a bearer token in the
    # cache table in the clear. Checked against updated_at so a new secret takes
    # effect at once; without it every ImportItemJob would fetch its own token.
    def access_token
      cached = TOKENS[id]
      return cached[:token] if cached && cached[:saved_at] == updated_at && Time.current < cached[:expires_at]

      body = request_token
      expires_at = Time.current + body.fetch("expires_in").to_i.seconds - TOKEN_EXPIRY_MARGIN
      entry = { token: body.fetch("access_token"), expires_at:, saved_at: updated_at }
      TOKENS[id] = entry
      entry[:token]
    end

    # raise_errors is off because Entra's AADSTS code, which says whether the
    # tenant, the client id or the secret is wrong, is only in the body.
    def request_token
      response = Http.connection(LOGIN_URL, timeout: ACCESS_TIMEOUT, raise_errors: false).post(
        "#{ERB::Util.url_encode(tenant)}/oauth2/v2.0/token",
        client_id: client_id,
        client_secret: client_secret,
        grant_type: "client_credentials",
        scope: GRAPH_SCOPE
      )
      body = parse(response)
      return body if response.success?

      raise Error, body["error_description"].to_s.lines.first&.strip.presence || "token request failed (#{response.status})"
    end

    def graph_error(response)
      error = parse(response)["error"] || {}
      error["message"].present? ? [error["code"], error["message"]].compact.join(": ") : "Graph answered #{response.status}"
    end

    def parse(response)
      JSON.parse(response.body.to_s)
    rescue JSON::ParserError
      {}
    end

    def base_url_must_be_a_sharepoint_site
      uri = URI.parse(base_url)
      unless uri.host.to_s.end_with?(".sharepoint.com")
        return errors.add(:base_url, "must be a sharepoint.com address")
      end
      return if uri.path.blank? || uri.path.match?(SITE_PATH)

      errors.add(:base_url, "must be the site's address, like https://example.sharepoint.com/sites/Team")
    rescue URI::InvalidURIError
      nil # the base class already reports this
    end
  end
end
