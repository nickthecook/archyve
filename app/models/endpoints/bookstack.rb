module Endpoints
  # The token pair is issued to a BookStack *user*, and the API returns only
  # what that user may see. This row is therefore an identity, not just an
  # address: whatever it can reach may end up surfaced under Archyve's access
  # model instead of BookStack's.
  class Bookstack < Endpoint
    ACCESS_TIMEOUT = 10

    store_accessor :config, :token_id
    credential :token_secret

    validates :base_url, presence: true
    validates :token_id, presence: true
    validates :token_secret, presence: true

    def self.permitted_keys = super + [:token_id, :token_secret]
    def self.form_component = Views::Settings::Endpoints::Forms::Bookstack

    def self.type_label = "BookStack"

    def self.description
      "A BookStack wiki. Needs an API token id and secret, issued to a BookStack user whose view of the wiki this endpoint inherits."
    end

    def auth_headers = { "Authorization" => "Token #{token_id}:#{token_secret}" }

    # The cheapest call that requires auth. Http's raise_error middleware turns
    # a rejected token into an exception, so there is no response to inspect.
    def access!
      client(timeout: ACCESS_TIMEOUT).get("/api/books", { count: 1 })
    end
  end
end
