require "faraday"
require "faraday/multipart"
require "faraday/retry"

# One place to build outbound HTTP connections so every service (Docling, Ollama
# via RubyLLM uses its own, sources later) shares the same middleware stack:
# retries with backoff, multipart uploads, and ActiveSupport::Notifications
# instrumentation (which the live pipeline stats will subscribe to).
module Http
  RETRY_OPTIONS = {
    max: 2,
    interval: 0.5,
    backoff_factor: 2,
    exceptions: [Faraday::TimeoutError, Faraday::ConnectionFailed]
  }.freeze

  # `raise_errors: false` leaves the response to the caller. Only a crawler
  # wants that: a 301 is a link to follow and a 404 is a fact about the site,
  # and both arrive as exceptions once `raise_error` is in the stack — which
  # throws away the response before anything can read it.
  def self.connection(base_url, timeout: 120, raise_errors: true)
    Faraday.new(url: base_url) do |f|
      f.request :multipart
      f.request :url_encoded
      f.request :retry, **RETRY_OPTIONS
      f.request :instrumentation # emits "request.faraday" on ActiveSupport::Notifications
      f.response :raise_error if raise_errors # turn 4xx/5xx into Faraday::Error subclasses
      f.options.timeout = timeout
      f.adapter Faraday.default_adapter
    end
  end
end
