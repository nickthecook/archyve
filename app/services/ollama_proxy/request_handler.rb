module OllamaProxy
  class RequestHandler
    def initialize(request, proxy)
      @request = request
      @proxy = proxy
    end

    def handle(&)
      formatted_response, raw_response = FormattedChatResponse.new(@proxy).generate(&)

      MessageCreator.new(
        message.conversation,
        @request.model
      ).create!("assistant", formatted_response, raw_response)
      @request.update_last_user_message(message.prompt)

      save_api_calls
    end

    def api_call
      @api_call ||= proxy_response.api_call
    end

    private

    def save_api_calls
      Rails.logger.silence do
        api_call.save!

        @proxy.api_call.update!(traceable: api_call)
      end
    end

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
