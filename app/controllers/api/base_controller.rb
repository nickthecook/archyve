module Api
  class BaseController < ActionController::API
    include ActionController::HttpAuthentication::Token::ControllerMethods

    # Arguments arrive as the JSON body itself; wrapping would add a copy of them
    # under the controller's name.
    wrap_parameters false

    # Before authenticate, so a refused call is recorded too.
    around_action(if: -> { ApiCall.recording_incoming? }) { |controller, action| ApiCalls::Inbound.around(controller, &action) }
    before_action :authenticate

    private

    def authenticate
      Current.api_key = authenticate_with_http_token { |token, _options| ApiKey.authenticate(token) }
      return Current.api_key.used! if Current.api_key

      response.headers["WWW-Authenticate"] = %(Bearer realm="Archyve")
      render_error :unauthorized, "unauthorized", "Send an API key as `Authorization: Bearer <key>`."
    end

    def render_error(status, code, message)
      render json: { error: code, message: }, status:
    end
  end
end
