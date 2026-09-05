require "faraday"
require "faraday/multipart"
require "faraday/retry"

# One place to build outbound HTTP connections so every service (Docling, Ollama
# via RubyLLM uses its own, connectors later) shares the same middleware stack:
# retries with backoff, multipart uploads, and ActiveSupport::Notifications
# instrumentation (which the live pipeline stats will subscribe to).
module Http
  RETRY_OPTIONS = {
    max: 2,
    interval: 0.5,
    backoff_factor: 2,
    exceptions: [Faraday::TimeoutError, Faraday::ConnectionFailed]
  }.freeze

  def self.connection(base_url, timeout: 120)
    Faraday.new(url: base_url) do |f|
      f.request :multipart
      f.request :url_encoded
      f.request :retry, **RETRY_OPTIONS
      f.request :instrumentation # emits "request.faraday" on ActiveSupport::Notifications
      f.response :raise_error    # turn 4xx/5xx into Faraday::Error subclasses
      f.options.timeout = timeout
      f.adapter Faraday.default_adapter
    end
  end
end
