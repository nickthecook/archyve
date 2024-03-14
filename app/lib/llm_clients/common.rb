module LlmClients
  class ClientError < StandardError; end
  class NetworkError < ClientError; end
  class UnsupportedServerError < ClientError; end

  class ResponseError < StandardError
    attr_reader :additional_info

    def initialize(message, additional_info)
      @additional_info = additional_info

      super(message)
    end
  end
end
