module ApiCalls
  # Records one request to Archyve's own API, around the controller action that
  # answers it. Like Recorder, a failure here is a log line, never a failed call.
  class Inbound
    def self.around(controller, &) = new(controller).record(&)

    def initialize(controller)
      @request = controller.request
      @response = controller.response
    end

    def record
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
    rescue StandardError => e
      error = e
      raise
    ensure
      save(started, error)
    end

    private

    def save(started, error)
      ApiCall.create!(
        incoming: true, kind: "tool",
        service_name: Current.api_key&.name || "unauthenticated",
        user: Current.user, api_key: Current.api_key,
        http_method: @request.method, url: @request.original_url,
        request_headers: Headers.redact(request_headers),
        request_body: Body.summarize(@request.raw_post),
        request_length: @request.raw_post&.length,
        **response_attributes(error),
        duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      )
    rescue StandardError => e
      Rails.logger.error("recording incoming api call failed: #{e.class}: #{e.message}")
    end

    def response_attributes(error)
      return { response_code: 500, error: "#{error.class}: #{error.message}" } if error

      {
        response_code: @response.status,
        response_headers: @response.headers.to_h,
        response_body: Body.summarize(@response.body),
        response_length: @response.body&.length
      }
    end

    def request_headers
      @request.headers.env
        .select { |name, _| name.start_with?("HTTP_") || name == "CONTENT_TYPE" }
        .to_h { |name, value| [name.delete_prefix("HTTP_").split("_").map(&:capitalize).join("-"), value] }
    end
  end
end
