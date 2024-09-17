module OllamaProxy
  class Proxy
    attr_reader :yielded, :response

    def initialize(request, traceable: nil)
      @incoming_request = request
      @last_response = nil
      @traceable = traceable
    end

    def get(&)
      @http_request = Net::HTTP::Get.new(url.to_s, **headers)
      stream(&)
    end

    def post(&)
      @http_request = Net::HTTP::Post.new(uri, **headers)
      @http_request.body = @incoming_request.body
      stream(&)
    end

    def delete
      @http_request = Net::HTTP::Delete.new(uri, **headers)
      @http_request.body = @incoming_request.body
      request
    end

    def code
      @last_response.code.to_i
    end

    def api_call
      @api_call ||= ApiCall.from_net_http("ollama_proxy", @http_request, @response, @traceable)
    end

    private

    def stream(&)
      @response_body = ""
      @yielded = false

      @response = stream_request(&)

      @response.body = @response_body
      Rails.logger.silence { api_call.save! }

      response unless @yielded
    end

    def request(request)
      @last_response = Net::HTTP.start(host, port) do |http|
        http.request(request)
      end

      store_api_call(service_name, request, full_response, response)

      @last_response.read_body
    end

    def stream_request(&)
      Net::HTTP.start(host, port) do |http|
        http.request(@http_request) do |incoming_response|
          @last_response = incoming_response

          if chunked?(incoming_response)
            incoming_response.read_body do |chunk|
              if block_given?
                yield chunk
                @yielded = true
              end

              @response_body << chunk
            end
          else
            @response_body << incoming_response.read_body
          end
        end
      end
    end

    def chunked?(response)
      response["Transfer-Encoding"] == "chunked"
    end

    def method
      @method ||= @incoming_request.method.downcase
    end

    def uri
      URI(url)
    end

    def url
      "#{server_uri}#{@incoming_request.path}"
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
      JSON.parse(@incoming_request.body)
    rescue JSON::ParserError => e
      Rails.log.warning("Failed to parse request body: #{e}")
      {}
    end
  end
end
