module Opp
  class Proxy
    def initialize(request)
      @request = request
      @last_response = nil
    end

    def get
      request = Net::HTTP::Get.new(url.to_s, **headers)
      @last_response = Net::HTTP.start(host, port) do |http|
        http.request(request)
      end
    end

    def post
      request = Net::HTTP::Post.new(uri, **headers)
      request.body = @request.raw_post
      if incoming_request_body["stream"] == false
        request(request)
      else
        stream(request)
      end
    end

    def code
      @last_response.code.to_i
    end

    private

    # TODO: when streaming to actual client, just send each chunk back as-is
    def stream(request)
      response = ""

      Net::HTTP.start(host, port) do |http|
        http.request(request) do |incoming_response|
          @last_response = incoming_response

          response << incoming_response.read_body
        end
      end

      response
    end

    def request(request)
      @last_response = Net::HTTP.start(host, port) do |http|
        http.request(request)
      end

      @last_response.read_body
    end

    def method
      @method ||= @request.request_method.downcase
    end

    def uri
      URI(url)
    end

    def url
      "#{protocol}://#{host}:#{port}#{@request.path}"
    end

    def protocol
      "http"
    end

    def host
      "shard"
    end

    def port
      11434
    end

    def headers
      { "Content-Type": "application/json" }
      # headers[:Authorization] = "Bearer #{@api_key}" if @api_key
    end

    def incoming_request_body
      JSON.parse(@request.raw_post)
    rescue JSON::ParserError => e
      Rails.log.warning("Failed to parse request body: #{e}")
      {}
    end
  end
end
