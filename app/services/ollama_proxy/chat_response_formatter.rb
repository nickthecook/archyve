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
      JSON.parse(chunk).dig("message", "content")
    end

    def processor
      @processor ||= MessageProcessor.new
    end
  end
end
