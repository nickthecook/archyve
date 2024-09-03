module Opp
  class OppController < ApiController
    def get
      proxy = Opp::Proxy.new(request)
      render json: proxy.get, status: proxy.code
    end

    def post
      proxy = Opp::Proxy.new(request)
      render json: proxy.post, status: proxy.code
    end
  end
end
