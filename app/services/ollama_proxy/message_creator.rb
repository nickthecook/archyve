module OllamaProxy
  class MessageCreator
    def initialize(conversation, chat_model)
      @conversation = conversation
      @chat_model = chat_model
    end

    def create!(role, content, raw_content = nil)
      Message.create!(
        conversation: @conversation,
        content:,
        raw_content:,
        author: author_for(role)
      )
    end

    private

    def author_for(role)
      if role == "user"
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
