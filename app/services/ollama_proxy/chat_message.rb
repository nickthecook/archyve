module OllamaProxy
  class ChatMessage
    def initialize(message_hash)
      @message_hash = message_hash
      @provider = detect_provider
    end

    def content
      # the first attempt to find content in the message works with Ollama's OpenAI chat route
      # the second attempt works with Ollama's chat route
      @content ||= if @provider == :ollama
        @message_hash["content"]
      elsif @provider == :openai
        @message_hash.dig("content", 0, "text")
      end
    end

    def content=(value)
      @content = value

      @message_hash["content"] = if @provider == :openai
        [{ "type" => "text", "text" => value }]
      else
        value
      end
    end

    def role
      @role ||= @message_hash["role"]
    end

    def to_h
      @message_hash
    end

    def to_json(*_args)
      @message_hash.to_json
    end

    def detect_provider
      if @message_hash["content"].is_a?(String)
        :ollama
      elsif @message_hash.dig("content", 0, "text").is_a?(String)
        :openai
      end
    end
  end
end
