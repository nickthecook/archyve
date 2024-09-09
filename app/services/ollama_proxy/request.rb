module OllamaProxy
  class Request
    attr_writer :body

    def initialize(controller_request)
      @controller_request = controller_request
    end

    def body
      @body ||= @controller_request.raw_post
    end

    def parsed_body
      @parsed_body ||= JSON.parse(body)
    rescue JSON::ParserError => e
      Rails.logger.warn("Failed to parse OPP request to #{path}: #{e}")
      nil
    end

    def method
      @method ||= @controller_request.request_method
    end

    def path
      @path ||= @controller_request.path
    end
  end
end
