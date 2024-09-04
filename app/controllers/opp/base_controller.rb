module Opp
  class BaseController < ActionController::Base
    protect_from_forgery with: :null_session

    rescue_from StandardError, with: :render_error

    protected

    def log_exception(exception)
      Rails.logger.error(
        "\n#{exception.class.name}: #{exception.message}\n#{exception.backtrace.join("\n")}"
      )
    end

    def render_error(exception)
      log_exception(exception)

      render json: { error: exception }, status: :internal_server_error
    end
  end
end
