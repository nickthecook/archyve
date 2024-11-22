module OllamaProxy
  class MessageMatcher
    def initialize(message, chat_message)
      @message = message
      @chat_message = chat_message
    end

    def match?
      return false if @message.author_type == "User" && @chat_message.role != "user"
      return false if @message.author_type == "ModelConfig" && @chat_message.role != "assistant"
      return false if @message.author_type == "System" && @chat_message.role != "system"

      content = @message.raw_content || @message.content
      return false if content != @chat_message.content

      true
    end
  end
end
