module V1
  class SettingsController < ApiController
    def index
      render json: { settings: settings.map { |setting| setting.attributes.slice(*visible_attrs) } }
    end

    def show
      render json: { setting: show_setting.attributes.slice(*visible_attrs) }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "No setting with key '#{requested_id}'." }, status: :not_found
    rescue StandardError => e
      render json: { error: e }, status: :internal_server_error
    end

    private

    def show_setting
      @show_setting ||= Setting.find_by!(key: requested_id)
    end

    def requested_id
      @requested_id ||= CGI.unescape(show_params[:id])
    end

    def show_params
      @show_params ||= params.slice!(:id).permit!
    end

    def visible_attrs
      %w[key value]
    end

    def settings
      Setting.where(target: nil)
    end
  end
end
