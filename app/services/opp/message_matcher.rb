module Opp
  class MessageMatcher
    def initialize(message, chat_message)
      @message = message
      @chat_message = chat_message
    end

    def match?
      return false if @message.author_type == "User" && @chat_message["role"] != "user"
      return false if @message.author_type == "ModelConfig" && @chat_message["role"] != "assistant"

      false if @message.content != @chat_message["content"]
    end
  end
end
