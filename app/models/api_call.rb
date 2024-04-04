class ApiCall < ApplicationRecord
  enum http_method: { get: 0, head: 1, post: 2, put: 3, delete: 4, options: 6, patch: 8 }, _prefix: true

  validate :valid_url?

  class << self
    def from_httparty_request(category, service_name, response)
      ApiCall.new(
        category:,
        service_name:,
        http_method:,
        url: response.request.uri.to_s,
        request_body: request_body_for_api_call(request_body),
        request_size: request_size(response),
        response_code: response.code,
        response_body: response_body_for_api_call(response),
        response_size: response_body_size(response)
      )
    end
  end

  private

  def valid_url?
    URI.parse(url)
  rescue URI::InvalidURIError
    errors.add(:url, I18n.t('activerecord.errors.models.api_call.attributes.url'))
  end
end
