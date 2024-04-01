module V1
  class ApiController < ActionController::Base
    CLIENT_ID_HEADER = "X-Client-Id".freeze

    before_action :authenticate_api_key!

    protect_from_forgery with: :null_session

    private

    def authenticate_api_key!
      client = client_from_request
      return render json: { error: "Unrecognized client_id" }, status: :unauthorized if client.nil?

      unless request.headers["Authorization"]
        return render json: { error: "No API key provided." }, status: :unauthorized
      end

      api_key = api_key_from_request
      return render json: { error: "Invalid API key" }, status: :unauthorized unless api_key

      return unless client.api_key != api_key

      render json: { error: "Unrecognized API key" }, status: :unauthorized unless @client
    end

    def client_from_request
      client_id = request.headers[CLIENT_ID_HEADER]
      return if client_id.blank?

      Client.find_by(client_id:)
    end

    def api_key_from_request
      header = request.headers["Authorization"]
      return if header.blank?
      return unless header.start_with?("Bearer ")

      value = header.split(" ").last
      return unless valid_base64?(value)

      value
    end

    def valid_base64?(value)
      Base64.strict_decode64(value)
      true
    rescue StandardError
      Rails.logger.info("oops")
      false
    end
  end
end
