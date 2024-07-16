module V1
  class VersionController < ApiController
    def show
      render json: { version: Rails.application.config.version }
    end
  end
end
