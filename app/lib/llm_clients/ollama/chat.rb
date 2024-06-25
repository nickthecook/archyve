module LlmClients
  module Ollama
    class Chat
      def initialize(messages)
        @messages = messages
      end

      def chat_history
        @chat_history ||= generate_chat_history
      end

      private

      def generate_chat_history
        # use message content only for all messages but the last
        messages = conversation_messages[..-2].map do |message|
          {
            role: role_for_message(message),
            content: message.content,
          }
        end

        # use the augmented prompt for the last message
        last_message = conversation_messages.last
        messages << {
          role: role_for_message(last_message),
          content: last_message.prompt || last_message.content,
        }
      end

      def role_for_message(message)
        return nil if message.author.nil?

        message.author.is_a?(User) ? "user" : "assistant"
      end

      def conversation_messages
        @conversation_messages ||= @messages.sort
      end
    end
  end
end
