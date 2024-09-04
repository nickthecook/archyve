module Opp
  class StreamingController < OppController
    include ActionController::Live

    def get
      response_body = @proxy.get do |chunk|
        response.stream.write chunk
      end

      if @proxy.yielded
        response.stream.close
      else
        render json: response_body, status: @proxy.code
      end
    end

    def post
      response_body = @proxy.post do |chunk|
        response.stream.write chunk
      end

      if @proxy.yielded
        response.stream.close
      else
        render json: response_body, status: @proxy.code
      end
    end
  end
end
