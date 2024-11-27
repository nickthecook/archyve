module OllamaProxy
  class MessageMatcher
    def initialize(message, chat_message)
      @message = message
      @chat_message = chat_message
    end

    def match?
      return false if user_message_false? || model_config_message_false? || system_message_false?

      content = @message.raw_content || @message.content
      return false if content != @chat_message.content

      true
    end

    private

    def user_message_false?
      @message.author_type == "User" && @chat_message.role != "user"
    end

    def model_config_message_false?
      @message.author_type == "ModelConfig" && @chat_message.role != "assistant"
    end

    def system_message_false?
      @message.author.nil? && @chat_message.role != "system"
    end
  end
end
