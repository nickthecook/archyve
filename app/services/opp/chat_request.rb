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
  end
end
