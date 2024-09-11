module OllamaProxy
  class ChatResponseFormatter
    attr_reader :formatted_response, :raw_response

    def initialize(proxy)
      @proxy = proxy

      @formatted_response = ""
      @raw_response = ""
    end

    def execute(&)
      @proxy.post do |chunk|
        yield chunk

        content = extract_content(chunk)
        formatted_message, raw_message = processor.append(content)

        @formatted_response << formatted_message
        @raw_response << raw_message
      end

      [@formatted_response, @raw_response]
    end

    private

    def extract_content(chunk)
      response_hash = parse_chunk(chunk)

      response_hash.dig("message", "content") || response_hash.dig("choices", 0, "delta", "content")
    end

    def parse_chunk(chunk)
      # newlines will only appear after a value JSON object, and only in OpenAI compatibility endpoints
      chunk = chunk.lines.first

      # ollama does this for OpenAI-compatible endpoints
      if chunk.start_with?("data: ")
        chunk.gsub!(/^data: /, "")
      end

      JSON.parse(chunk)
    end

    def processor
      @processor ||= MessageProcessor.new
    end
  end
end
