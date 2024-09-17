module OllamaProxy
  class OllamaProxyController < OllamaProxy::BaseController
    protect_from_forgery with: :null_session

    before_action :set_request
    before_action :set_proxy
    before_action :set_handler

    def get
      render json: @handler.handle, status: @proxy.code
    end

    def post
      render json: @handler.handle, status: @proxy.code
    end

    def delete
      render json: @handler.handle, status: @proxy.code
    end

    protected

    def set_handler
      @handler = OllamaProxy::RequestHandler.new(@opp_request, @proxy)
    end

    def set_request
      @opp_request = OllamaProxy::Request.new(request)
    end

    def set_proxy
      @proxy = OllamaProxy::Proxy.new(@opp_request)
    end
  end
end
