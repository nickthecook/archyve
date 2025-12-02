module OllamaProxy
  class FormattedChatResponse
    attr_reader :formatted_response, :raw_response

    def initialize(proxy)
      @proxy = proxy

      @formatted_response = ""
      @raw_response = ""
    end

    def generate(&)
      response = @proxy.post do |chunk|
        # yield the content the server sent, exactly as the server sent it
        yield chunk

        content = extract_content(chunk)
        formatted_message, raw_message = processor.append(content)

        @formatted_response << formatted_message
        @raw_response << raw_message
      end

      unless @proxy.yielded
        content = extract_content(response.body)
        @formatted_response, @raw_response = processor.append(content)
      end

      # return the complete response, in formatted and unformatted forms
      [@formatted_response, @raw_response]
    end

    private

    def extract_content(chunk)
      response_hash = parse_chunk(chunk)

      # TODO: raise the error, don't return it as content
      content = response_hash.dig("message", "content") ||
        response_hash.dig("choices", 0, "delta", "content") ||
        response_hash.dig("choices", 0, "message", "content") ||
        response_hash["error"] ||
        chunk
      content = content.to_s unless content.is_a?(String)

      content
    end

    def parse_chunk(chunk)
      # when streaming, newlines will only appear after a value JSON object, and only in OpenAI compatibility endpoints
      line = chunk.lines.first

      # ollama does this for OpenAI-compatible endpoints
      if line.start_with?("data: ")
        line.gsub!(/^data: /, "")
      end

      JSON.parse(line)
    rescue JSON::ParserError => e
      # when using OPP non-streaming in from of an OpenAI enpoint, the response will sometimes come back with newlines
      # in the JSON, the way you'd write it for a human
      Rails.logger.debug { "Error parsing first line of response as JSON: #{e.message}; falling back to chunk" }

      JSON.parse(chunk)
    end

    def processor
      @processor ||= MessageProcessor.new
    end
  end
end
