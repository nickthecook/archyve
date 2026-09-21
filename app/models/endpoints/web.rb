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

    # How Archyve introduces itself to this site. On the endpoint rather than on
    # the crawler because it identifies *us*, not one caller: `#access!` and the
    # crawl have to present the same name, or a site that filters on User-Agent
    # disagrees with itself about whether this endpoint is reachable. It is also
    # the token robots.txt groups are matched against, so a site that wants to
    # refuse Archyve specifically has something to name.
    #
    # Not on Endpoint itself: BookStack is an API reached with a token, and
    # changing what its requests carry would be a change to a working
    # integration for no reason.
    USER_AGENT = "Archyve/2 (+https://github.com/nickthecook/archyve2)".freeze

    # What to send on every request.
    SCHEMES = %w[none basic header].freeze

    store_accessor :config, :auth_scheme, :username, :header_name, :path_prefix
    credential :password, :header_value

    validates :base_url, presence: true
    validates :auth_scheme, inclusion: { in: SCHEMES }, allow_blank: true
    validate :origin_must_have_no_path, if: -> { base_url.present? }
    validate :path_prefix_must_be_a_path, if: -> { path_prefix.present? }

    with_options if: :basic? do
      validates :username, presence: true
      validates :password, presence: true
    end

    # Not header_name: blank means Authorization, which is what the form's
    # placeholder promises.
    validates :header_value, presence: true, if: :static_header?

    def self.permitted_keys
      super + [:auth_scheme, :username, :password, :header_name, :header_value, :path_prefix]
    end
    def self.form_component = Views::Settings::Endpoints::Forms::Web

    def self.type_label = "Website"

    def self.description
      "A website Archyve crawls over HTTP. Optionally authenticated, and optionally confined to one path."
    end

    def scheme = auth_scheme.presence || "none"
    def basic? = scheme == "basic"
    def static_header? = scheme == "header"

    def client(timeout: DEFAULT_TIMEOUT, raise_errors: true)
      super.tap { |connection| connection.headers["User-Agent"] = USER_AGENT }
    end

    def auth_headers
      if basic?
        { "Authorization" => "Basic #{Base64.strict_encode64("#{username}:#{password}")}" }
      elsif static_header?
        { header_name.presence || DEFAULT_HEADER_NAME => header_value }
      else
        {}
      end
    end

    # The part of the site this endpoint actually reaches, which is the useful
    # thing to check: a host whose front page is fine while /docs 404s is not a
    # working endpoint. `raise_error` is left in the stack here deliberately —
    # unlike the crawl, a 401 or a 503 in answer to this is the answer.
    def access!
      client(timeout: ACCESS_TIMEOUT).get(path_prefix.presence || "/")
    end

    private

    # `base_url` goes straight to Faraday, and `#client` is shared with the
    # robots.txt fetch and every other root-relative request, so it stays the
    # bare origin. Confining the endpoint is what `path_prefix` is for.
    def origin_must_have_no_path
      uri = URI.parse(base_url)
      return if uri.path.blank? && uri.query.blank?

      errors.add(:base_url, "must be just the site's address — put the path in the Path field below")
    rescue URI::InvalidURIError
      nil # the base class already reports this
    end

    def path_prefix_must_be_a_path
      return if path_prefix.to_s.start_with?("/") && !path_prefix.to_s.include?("://")

      errors.add(:path_prefix, "must be a path beginning with /, not a full address")
    end
  end
end
