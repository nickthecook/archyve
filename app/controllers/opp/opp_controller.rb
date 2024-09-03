module Opp
  class OppController < ActionController::Base
    include ActionController::Live

    def get
      proxy = Opp::Proxy.new(request)

      render json: proxy.get, status: proxy.code
    end

    def post
      proxy = Opp::Proxy.new(request)
      if stream?
        proxy.post do |chunk|
          response.stream.write chunk
        end

        response.stream.close
      else
        response_body = proxy.post
        render json: response_body, status: proxy.code
      end
    end

    private

    def stream?
      parsed_post_body["stream"].nil? || parsed_post_body["stream"] == true
    end

    def parsed_post_body
      @parsed_post_body ||= JSON.parse(request.raw_post)
    end
  end
end
