module OllamaProxy
  class ChatRequestHandler < RequestHandler
    def handle(&)
      @message = chat_augmentor.execute
      # if there are no collections to search, prompt will remain nil
      @request.update_last_user_message(@message.prompt || @message.content)

      formatted_response, raw_response = FormattedChatResponse.new(@proxy).generate(&)

      MessageCreator.new(
        @message.conversation,
        @request.model
      ).create!("assistant", formatted_response, raw_response)

      save_api_calls

      @proxy.response
    end

    private

    def chat_augmentor
      @chat_augmentor ||= ChatAugmentor.new(@request, User.first)
    end

    def proxy_response
      ProxyResponse.new(@request.controller_request, @proxy.response, traceable: chat_augmentor.conversation)
    end
  end
end
