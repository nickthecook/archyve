module OllamaProxy
  class AugmentingController < StreamingController
    before_action :return_if_no_messages

    def chat
      ChatRequestHandler.new(@opp_request, @proxy).handle do |chunk|
        response.stream.write(chunk)
      end

      if @proxy.yielded
        response.stream.close
      else
        render plain: @proxy.response.body, status: @proxy.code
      end
    end

    protected

    def set_request
      @opp_request = ChatRequest.new(request)
    end

    private

    def return_if_no_messages
      head :no_content if @opp_request.messages_with_content.empty?
    end
  end
end
