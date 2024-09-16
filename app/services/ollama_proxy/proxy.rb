module OllamaProxy
  class Proxy
    attr_reader :yielded

    def initialize(request)
      @request = request
      @last_response = nil
    end

    def get(&)
      request = Net::HTTP::Get.new(url.to_s, **headers)
      stream(request, &)
    end

    def post(&)
      request = Net::HTTP::Post.new(uri, **headers)
      request.body = @request.body
      stream(request, &)
    end

    def delete
      request = Net::HTTP::Delete.new(uri, **headers)
      request.body = @request.body
      request(request)
    end

    def code
      @last_response.code.to_i
    end

    private

    def stream(request)
      response = ""
      @yielded = false

      full_response = Net::HTTP.start(host, port) do |http|
        http.request(request) do |incoming_response|
          @last_response = incoming_response

          if chunked?(incoming_response)
            incoming_response.read_body do |chunk|
              if block_given?
                yield chunk
                @yielded = true
              end

              response << chunk
            end
          else
            response << incoming_response.read_body
          end
        end
      end

      ApiCall.from_net_http(service_name, request, full_response, nil).save!

      response unless @yielded
    end

    def request(request)
      @last_response = Net::HTTP.start(host, port) do |http|
        http.request(request)
      end

      ApiCall.from_net_http(service_name, request, @last_response, nil).save!

      @last_response.read_body
    end

    def store_api_call(service_name, request, response, response_body = nil, traceable: nil)
      response.body = response_body if response_body
      ApiCall.from_net_http(service_name, request, response, traceable || @traceable).save!
    end

    def chunked?(response)
      response["Transfer-Encoding"] == "chunked"
    end

    def method
      @method ||= @request.method.downcase
    end

    def uri
      URI(url)
    end

    def url
      "#{server_uri}#{@request.path}"
    end

    def protocol
      server_uri.scheme
    end

    def host
      server_uri.host
    end

    def port
      server_uri.port
    end

    def server_uri
      @server_uri ||= URI(model_server.url)
    end

    def model_server
      @model_server ||= ModelServer.active_server
    end

    def headers
      { "Content-Type": "application/json" }
      # headers[:Authorization] = "Bearer #{@api_key}" if @api_key
    end

    def incoming_request_body
      JSON.parse(@request.body)
    rescue JSON::ParserError => e
      Rails.log.warning("Failed to parse request body: #{e}")
      {}
    end

    def service_name
      "ollama_proxy"
    end
  end
end
