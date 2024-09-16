module OllamaProxy
  class AugmentingController < StreamingController
    before_action :return_if_no_messages
    before_action :augment_prompt
    before_action :update_request

    def chat
      response_body = ""
      formatted_response, raw_response = ChatResponseFormatter.new(@proxy).execute do |chunk|
        response.stream.write(chunk)
        response_body << chunk
      end

      MessageCreator.new(
        @message.conversation,
        @opp_request.model
      ).create!("assistant", formatted_response, raw_response)

      store_api_call(response_body)
    ensure
      response.stream.close
    end

    protected

    def set_request
      @opp_request = ChatRequest.new(request)
    end

    private

    def store_api_call(response_body)
      logger.silence do
        proxy_response(response_body).api_call.save!
      end
    end

    def proxy_response(response_body)
      ProxyResponse.new(request, 200, response.headers, response_body, response_body.length)
    end

    def return_if_no_messages
      head :no_content if @opp_request.messages_with_content.empty?
    end

    def augment_prompt
      # TODO: when authn is implemented, find User based on Client
      @message = ChatAugmentor.new(@opp_request, User.first).execute
    end

    def update_request
      return if @opp_request.messages_with_content.empty?

      @opp_request.update_last_user_message(@message.prompt)
    end
  end
end
