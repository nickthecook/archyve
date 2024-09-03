module Opp
  class StreamingController < OppController
    include ActionController::Live

    def post
      if stream?
        @proxy.post do |chunk|
          response.stream.write chunk
        end

        response.stream.close
      else
        response_body = @proxy.post
        render json: response_body, status: @proxy.code
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
