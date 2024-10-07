module OllamaProxy
  # rubocop:disable Rails/ApplicationController
  # TODO: move browser auth stuff to subclass of ApplicationController so we can
  # inherit from that class here and make rubocop happy?
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
  # rubocop:enable Rails/ApplicationController
end
