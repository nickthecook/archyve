module Opp
  class ChatRequest < Request
    def model
      parsed_body["model"]
    end

    def messages
      parsed_body["messages"] || []
    end

    def messages_with_content
      @messages_with_content ||= messages.select { |message| message["content"].present? }
    end

    def last_user_message
      @last_user_message ||= messages_with_content.reverse_each.find do |message|
        message["role"] == "user"
      end
    end

    def update_last_user_message(content)
      last_user_message["content"] = content

      @body = @parsed_body.to_json
    end
  end
end
