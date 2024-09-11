module OllamaProxy
  class ChatRequest < Request
    def model
      parsed_body["model"]
    end

    def messages
      return [] if parsed_body["messages"].blank?

      @messages ||= parsed_body["messages"].map do |message|
        ChatMessage.new(message)
      end
    end

    def messages_with_content
      @messages_with_content ||= messages.select { |message| message.content.present? }
    end

    def last_user_message
      @last_user_message ||= messages.reverse_each.find do |message|
        message.role == "user"
      end
    end

    def update_last_user_message(content)
      last_user_message.content = content

      rebuild_body_from_messages
    end

    private

    def rebuild_body_from_messages
      @parsed_body["messages"] = messages.map(&:to_h)
      @body = @parsed_body.to_json
    end
  end
end
