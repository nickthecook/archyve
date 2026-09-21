module Endpoints
  # A website, named by its origin. Everything under it that a Sources::Web is
  # pointed at becomes documents; the path prefix lives on the source, so one
  # site can feed several collections from several subtrees.
  #
  # Authentication is whatever a crawler can carry on every request without a
  # session: HTTP Basic, or a static header (a bearer token, an API key, a
  # proxy's shared secret). Cookie and form login are out of scope — they need
  # a login round-trip, expiry handling and a renewal story, which is a
  # different feature rather than another option in this picker.
  class Web < Endpoint
    ACCESS_TIMEOUT = 15
    DEFAULT_HEADER_NAME = "Authorization".freeze

    # What to send on every request.
    SCHEMES = %w[none basic header].freeze

    store_accessor :config, :auth_scheme, :username, :header_name
    credential :password, :header_value

    validates :base_url, presence: true
    validates :auth_scheme, inclusion: { in: SCHEMES }, allow_blank: true
    validate :origin_must_have_no_path, if: -> { base_url.present? }

    with_options if: :basic? do
      validates :username, presence: true
      validates :password, presence: true
    end

    # Not header_name: blank means Authorization, which is what the form's
    # placeholder promises.
    validates :header_value, presence: true, if: :static_header?

    def self.permitted_keys = super + [:auth_scheme, :username, :password, :header_name, :header_value]
    def self.form_component = Views::Settings::Endpoints::Forms::Web

    def self.type_label = "Website"

    def self.description
      "A website Archyve crawls over HTTP. Optionally authenticated with HTTP Basic or a fixed header."
    end

    def scheme = auth_scheme.presence || "none"
    def basic? = scheme == "basic"
    def static_header? = scheme == "header"

    def auth_headers
      if basic?
        { "Authorization" => "Basic #{Base64.strict_encode64("#{username}:#{password}")}" }
      elsif static_header?
        { header_name.presence || DEFAULT_HEADER_NAME => header_value }
      else
        {}
      end
    end

    # The origin itself. A site that answers at all is reachable; whether any
    # particular subtree is crawlable is the source's question, not the
    # endpoint's. `raise_error` is left in the stack here deliberately — unlike
    # the crawl, a 401 or a 503 on the front page is the answer.
    def access!
      client(timeout: ACCESS_TIMEOUT).get("/")
    end

    private

    # A path here would be wrong twice over: it is the source's to hold, and
    # Faraday resolves a relative request against a base *path* by replacing its
    # last segment, so every crawled URL would be built off a surprising root.
    def origin_must_have_no_path
      uri = URI.parse(base_url)
      return if uri.path.blank? && uri.query.blank?

      errors.add(:base_url, "must be just the site's address — put the path on the source instead")
    rescue URI::InvalidURIError
      nil # the base class already reports this
    end
  end
end
