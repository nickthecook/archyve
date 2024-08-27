class ApiCall < ApplicationRecord
  belongs_to :traceable, polymorphic: true, optional: true

  enum http_method: { get: 0, post: 1, put: 2, delete: 3, patch: 4, head: 5 }, _prefix: :http_method

  class << self
    # rubocop: disable Metrics/AbcSize
    def from_httparty(service_name, response, traceable = nil)
      request = response.request

      api_call = new(
        service_name:,
        http_method: http_method_from_httparty(request),
        url: request.uri.to_s,
        headers: request.options[:headers],
        body: json_body(request.raw_body),
        body_length: request.raw_body&.length,
        response_code: response.code,
        response_headers: response.headers,
        response_body: json_body(response.body),
        response_length: response.body.length
      )

      api_call.traceable = traceable if traceable
      api_call
    end

    def from_net_http(service_name, request, response, traceable = nil)
      api_call = new(
        service_name:,
        http_method: request.method.downcase,
        url: request.uri.to_s,
        headers: request.to_hash,
        body: json_body(request.body),
        body_length: request.body.length,
        response_code: response.code,
        response_headers: response.to_hash,
        response_body: json_body(response.body),
        response_length: response.body.length
      )

      api_call.traceable = traceable if traceable
      api_call
    end
    # rubocop: enable Metrics/AbcSize

    def from_faraday(service_name, request:, response:, traceable: nil)
      api_call = new(
        service_name:,
        url: request[:url],
        http_method: request[:http_method],
        headers: request[:headers],
        body: json_body(request[:body]),
        body_length: request[:body].length,
        response_headers: response[:headers],
        response_code: response[:status],
        response_body: json_body(response[:body]),
        response_length: response[:body]&.length || 0
      )
      api_call.traceable = traceable if traceable
      api_call
    end

    private

    def json_body(body)
      return if body.nil?

      JSON.parse(body)
    rescue JSON::ParserError, TypeError
      body
    end

    def http_method_from_httparty(request)
      request.http_method.name.split("::").last.downcase
    end
  end
end
