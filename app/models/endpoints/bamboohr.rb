module Endpoints
  # A BambooHR company's company files, read with one user's API key. BambooHR
  # permissions every request as that user, so this row is an identity in the
  # same sense as Endpoints::Bookstack.
  class Bamboohr < Endpoint
    ACCESS_TIMEOUT = 15

    Error = Class.new(StandardError)

    credential :api_key

    validates :base_url, presence: true
    validates :api_key, presence: true
    validate :base_url_must_be_a_bamboohr_company, if: -> { base_url.present? }

    def self.permitted_keys = super + [:api_key]
    def self.form_component = Views::Settings::Endpoints::Forms::Bamboohr

    def self.type_label = "BambooHR"

    def self.description
      "A BambooHR company's company files. Needs an API key whose user can see them."
    end

    def client(**)
      super.tap { |connection| connection.headers["Accept"] = "application/json" }
    end

    # The key is the username; BambooHR ignores the password.
    def auth_headers = { "Authorization" => "Basic #{Base64.strict_encode64("#{api_key}:x")}" }

    def api(timeout: DEFAULT_TIMEOUT) = ::Bamboohr::Api.new(self, timeout:)

    # A valid key whose user can't see company files is the likely mistake, and
    # a bare 403 doesn't say which half is wrong.
    def access!
      api(timeout: ACCESS_TIMEOUT).categories
    rescue Faraday::ForbiddenError
      raise Error, "this API key's user doesn't have access to company files"
    rescue Faraday::UnauthorizedError
      raise Error, "BambooHR didn't accept this API key"
    end

    private

    def base_url_must_be_a_bamboohr_company
      uri = URI.parse(base_url)
      return if uri.host.to_s.end_with?(".bamboohr.com") && uri.path.blank?

      errors.add(:base_url, "must be your company's address, like https://example.bamboohr.com")
    rescue URI::InvalidURIError
      nil # the base class already reports this
    end
  end
end
