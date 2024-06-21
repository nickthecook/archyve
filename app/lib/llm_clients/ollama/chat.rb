module LlmClients
  module Ollama
    class Chat
      def initialize(conversation)
        @conversation = conversation
      end

      def prompt
        {
          model: @conversation.model_config.model,
          messages:,
        }
      end

      private

      def messages
        @conversation.messages.map do |message|
          {
            role: role_for_message(message),
            content: message.content,
          }
        end
      end

      def role_for_message(message)
        return nil if message.author.nil?

        message.author.is_a?(User) ? "user" : "assistant"
      end
    end
  end
end
