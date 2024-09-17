module OllamaProxy
  class ProxyResponse
    attr_reader :request, :code, :body, :length

    def initialize(net_http_request, net_http_response, traceable:)
      @request = net_http_request
      @response = net_http_response
      @traceable = traceable

      @code = @response.code
      @body = @response.body
    end

    def api_call
      @api_call ||= begin
        api_call = new_api_call

        api_call.incoming = true

        api_call
      end
    end

    private

    def new_api_call
      ApiCall.from_controller_request("ollama_proxy", @request, @response, traceable: @traceable)
    end
  end
end
