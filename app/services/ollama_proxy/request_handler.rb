module OllamaProxy
  class RequestHandler
    def initialize(request, proxy)
      @request = request
      @proxy = proxy
    end

    def handle(&)
      response = @proxy.execute(&)

      save_api_calls

      response
    end

    def api_call
      @api_call ||= proxy_response.api_call
    end

    private

    def save_api_calls
      Rails.logger.silence do
        api_call.save!

        @proxy.api_call.update!(traceable: api_call)
      end
    end

    def proxy_response
      ProxyResponse.new(@request.controller_request, @proxy.response)
    end
  end
end
