class ApiCall < ApplicationRecord
  belongs_to :traceable, optional: true

  enum http_method: { get: 0, post: 1, put: 2, delete: 3, patch: 4, head: 5 }, _prefix: :http_method

  class << self
    # there's no way to resolve AbcSize that doesn't make the code ugly
    # rubocop: disable Metrics/AbcSize
    def from_net_http(service_name, request, response, traceable)
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

    private

    def json_body(body)
      JSON.parse(body)
    rescue JSON::ParserError
      body
    end
  end
end
