require "faraday"

module ApiCalls
  # Faraday middleware that writes an ApiCall per outbound call.
  #
  # Installed innermost in both stacks — below :json on the request and response
  # side — so bodies are recorded as they cross the wire rather than as the
  # hashes either end works with. That position also puts it inside
  # :raise_error, so a 4xx is recorded before the exception is raised.
  #
  # Nothing here may break the call it is observing. Every failure in this class
  # ends as a log line and an unrecorded call.
  class Recorder < Faraday::Middleware
    REDACTED = "[REDACTED]".freeze
    SECRET_HEADERS = /\A(?:authorization|cookie|set-cookie|x-api-key|api-key)\z/i

    def initialize(app, service_name: nil)
      super(app)
      @service_name = service_name
    end

    def call(env)
      kind = Kind.for(env.url)
      return @app.call(env) if kind.nil? || !ApiCall.recording?

      record(env, kind)
    end

    private

    def record(env, kind)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      stream, request = prepare(env, kind)
      return @app.call(env) if request.nil?

      begin
        @app.call(env).on_complete { |completed| save(request, started, completed:, stream:) }
      rescue StandardError => e
        save(request, started, error: e)
        raise
      end
    end

    # Nils when recording itself went wrong, which leaves the call to go out
    # unrecorded. Deliberately not wrapped around `@app.call`: a retry of a call
    # that already left is worse than a missing row.
    def prepare(env, kind)
      [tee_stream(env), request_attributes(env, kind)]
    rescue StandardError => e
      Rails.logger.error("preparing api call record failed: #{e.class}: #{e.message}")
      [nil, nil]
    end

    # A streamed response body never reaches env.body: RubyLLM consumes it
    # through on_data, so a recorded chat would otherwise have a request and no
    # answer. Splatted because Faraday 1 and 2 hand the handler different
    # arguments, and this has to pass on whatever it was given.
    def tee_stream(env)
      original = env.request.on_data
      return nil if original.nil?

      buffer = +""
      env.request.on_data = proc do |*args|
        buffer << args.first.to_s
        original.call(*args)
      end
      buffer
    end

    def request_attributes(env, kind)
      {
        service_name: @service_name || env.url.host,
        kind: kind,
        http_method: env.method.to_s,
        url: env.url.to_s,
        request_headers: redact(env.request_headers),
        request_body: Body.summarize(env.body),
        request_length: length_of(env.body),
        traceable: Current.api_call_traceable
      }
    end

    def response_attributes(env, stream)
      body = stream || env.body

      {
        response_code: env.status,
        response_headers: redact(env.response_headers),
        response_body: Body.summarize(body),
        response_length: length_of(body),
        streamed: !stream.nil?
      }
    end

    def redact(headers)
      headers.to_h.to_h { |name, value| [name, name.to_s.match?(SECRET_HEADERS) ? REDACTED : value] }
    end

    def length_of(body) = body.respond_to?(:length) ? body.length : nil

    # Builds the response half in here rather than at the call site so that a
    # failure reading the response is caught by the same rescue as a failed
    # write.
    def save(request, started, completed: nil, stream: nil, error: nil)
      response = error ? { error: "#{error.class}: #{error.message}" } : response_attributes(completed, stream)
      elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

      ApiCall.create!(**request, **response, duration_ms: elapsed)
    rescue StandardError => e
      Rails.logger.error("recording api call failed: #{e.class}: #{e.message}")
    end
  end
end
