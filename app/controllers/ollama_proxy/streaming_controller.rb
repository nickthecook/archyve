module OllamaProxy
  class StreamingController < OllamaProxyController
    include ActionController::Live

    before_action :set_content_type_header

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

    protected

    def set_content_type_header
      response.headers['Content-Type'] = 'application/json'
    end
  end
end
