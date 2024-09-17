module OllamaProxy
  class ChatRequestHandler < RequestHandler
    def handle(&)
      chat_augmentor.execute
      @request.update_last_user_message(message.prompt)

      formatted_response, raw_response = FormattedChatResponse.new(@proxy).generate(&)

      MessageCreator.new(
        message.conversation,
        @request.model
      ).create!("assistant", formatted_response, raw_response)

      save_api_calls

      @proxy.response
    end

    private

    def message
      # TODO: when authn is implemented, find User based on Client
      @message ||= chat_augmentor.execute
    end

    def chat_augmentor
      @chat_augmentor ||= ChatAugmentor.new(@request, User.first)
    end

    def proxy_response
      ProxyResponse.new(@request.controller_request, @proxy.response, traceable: chat_augmentor.conversation)
    end
  end
end
