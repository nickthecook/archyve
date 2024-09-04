module Opp
  class MessageCreator
    def initialize(conversation, chat_model)
      @conversation = conversation
      @chat_model = chat_model
    end

    def create!(chat_message)
      Message.create!(
        conversation: @conversation,
        content: chat_message["content"],
        author: author_for(chat_message)
      )
    end

    private

    def author_for(chat_message)
      if chat_message["role"] == "user"
        # TODO: when we have a Client, use its User
        User.first
      else
        model_config
      end
    end

    def model_config
      @model_config ||= ModelConfig.find_or_create_by(model: @chat_model) do |model_config|
        model_config.name = @chat_model
        model_config.available = true
      end
    end
  end
end
