module Opp
  class OppController < ActionController::Base
    protect_from_forgery with: :null_session

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

    private

    def set_proxy
      @proxy = Opp::Proxy.new(request)
    end
  end
end
