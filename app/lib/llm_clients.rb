module LlmClients
  class ClientError < StandardError; end
  class NetworkError < ClientError; end
  class UnsupportedServerError < ClientError; end
  class RetryableError < StandardError; end

  class ResponseError < StandardError
    attr_reader :additional_info

    def initialize(message, additional_info)
      @additional_info = additional_info

      super(message)
    end

    def to_s
      "#{self.class.name}: #{super}: #{additional_info.join("; ")}"
    end
  end
end
