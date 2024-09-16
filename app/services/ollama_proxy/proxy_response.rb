module OllamaProxy
  class ProxyResponse
    attr_reader :request, :code, :body, :length

    def initialize(net_http_request, code, headers, body, length)
      @request = net_http_request
      @code = code
      @headers = headers
      @body = body
      @length = length
    end

    def api_call(traceable: nil)
      api_call = ApiCall.new(
        service_name: "ollama_proxy",
        url: request.url,
        http_method: request.method.downcase,
        headers:,
        body: json_body(request_body),
        body_length: request_body.length,
        response_code: @code,
        response_headers: @headers,
        response_body: json_body(body),
        response_length: @body.length,
        incoming: true
      )

      api_call.traceable = traceable if traceable
      api_call
    end

    private

    def headers
      @headers ||= parse_headers
    end

    def parse_headers
      http_headers = @request.headers.to_h.select do |key, _value|
        key.start_with?("HTTP_")
      end
      http_headers.modify_keys! { |key| key.gsum(/^HTTP_/, "") }.downcase

      content_headers = @request.headers.to_h.select do |key, _value|
        key.start_with?("CONTENT_")
      end
      content_headers.modify_keys!(&:downcase)

      http_headers.merge!(content_headers)
    end

    def json_body(body)
      return if body.nil?

      JSON.parse(body)
    rescue JSON::ParserError, TypeError
      body
    end

    def request_body
      @request_body ||= @request.body.read
    end
  end
end
