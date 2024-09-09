module OllamaProxy
  class OllamaProxyController < OllamaProxy::BaseController
    protect_from_forgery with: :null_session

    before_action :set_request
    before_action :set_proxy

    def get
      render json: @proxy.get, status: @proxy.code
    end

    def post
      response_body = @proxy.post
      render json: response_body, status: @proxy.code
    end

    def delete
      render json: @proxy.delete, status: @proxy.code
    end

    protected

    def set_request
      @opp_request = OllamaProxy::Request.new(request)
    end

    def set_proxy
      @proxy = OllamaProxy::Proxy.new(@opp_request)
    end
  end
end
