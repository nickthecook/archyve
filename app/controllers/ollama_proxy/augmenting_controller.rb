module OllamaProxy
  class AugmentingController < StreamingController
    before_action :return_if_no_messages

    def chat
      RequestHandler.new(@opp_request, @proxy).handle do |chunk|
        response.stream.write(chunk)
      end
    ensure
      response.stream.close
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
