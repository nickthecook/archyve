module OllamaProxy
  class StreamingController < OllamaProxyController
    include ActionController::Live

    def get
      http_response = @handler.handle do |chunk|
        response.stream.write chunk
      end

      if @proxy.yielded
        response.stream.close
      else
        render json: http_response.body, status: @proxy.code
      end
    end

    def post
      http_response = @handler.handle do |chunk|
        response.stream.write chunk
      end

      if @proxy.yielded
        response.stream.close
      else
        render json: http_response, status: @proxy.code
      end
    end
  end
end
