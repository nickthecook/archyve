module Crawl
  # One GET, and a verdict on it.
  #
  # Redirects are *not* followed during a crawl. A 3xx resolves its own row as
  # `redirected` and its target is discovered as a separate item, which keeps
  # every URL fetched exactly once and accounted for exactly once — the thing a
  # transparent redirect-follower quietly gives up. `#get` will chase a hop when
  # asked, which re-reading a known document needs and the crawl loop does not.
  class Fetcher
    MAX_REDIRECTS = 3

    HTML_TYPES = ["text/html", "application/xhtml+xml"].freeze

    # What came back, in the vocabulary SourceSyncItem records.
    Response = Data.define(:url, :status, :body, :content_type, :location, :disposition, :error) do
      def ok? = disposition == :ok
      def redirect? = disposition == :redirected
    end

    def initialize(client:, delay: nil)
      @client = client
      @delay = delay.to_f
      @next_allowed_at = Time.current
    end

    def get(url, follow: 0)
      response = fetch(url)
      return response unless response.redirect? && follow.positive? && response.location

      get(response.location, follow: follow - 1)
    end

    private

    attr_reader :client, :delay

    def fetch(url)
      wait_for_politeness
      response = client.get(url)

      Response.new(
        url: url,
        status: response.status,
        body: response.body,
        content_type: response.headers["content-type"].to_s.split(";").first&.strip,
        location: response.headers["location"],
        disposition: disposition_for(response),
        error: nil
      )
    rescue Faraday::TimeoutError => e
      failure(url, :timeout, e)
    rescue Faraday::ConnectionFailed => e
      failure(url, :connection_failed, e)
    rescue StandardError => e
      failure(url, :failed, e)
    end

    def disposition_for(response)
      case response.status
      when 200 then HTML_TYPES.include?(content_type_of(response)) ? :ok : :nothing_readable
      when 204, 205, 206 then :nothing_readable
      when 300..399 then response.headers["location"].present? ? :redirected : :nothing_readable
      when 401, 403 then :forbidden
      when 404, 410 then :not_found
      when 500..599 then :server_error
      else :failed
      end
    end

    def content_type_of(response)
      response.headers["content-type"].to_s.split(";").first&.strip&.downcase
    end

    def failure(url, disposition, error)
      Response.new(url: url, status: nil, body: nil, content_type: nil, location: nil,
        disposition: disposition, error: error)
    end

    # Crawl-delay is a property of the host, so it is kept here rather than at
    # the call site — every request through this fetcher is spaced, including
    # the redirect hops that the caller never sees.
    def wait_for_politeness
      return if delay.zero?

      pause = @next_allowed_at - Time.current
      sleep(pause) if pause.positive?
      @next_allowed_at = Time.current + delay
    end
  end
end
