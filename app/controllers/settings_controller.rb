class SettingsController < ApplicationController
  before_action :set_setting, only: [:update]

  def index
    @model_server = ModelServer.new
  end

  def update
    update_setting(setting_params[:value])

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Setting saved."
        render turbo_stream: turbo_stream.replace(user_dom_id("notice"), partial: "shared/notice")
      end
      format.html do
        flash[:notice] = "Setting saved."
        redirect_to params[:redirect_path] || settings_path
      end
    end
  end

  def create_model_server
    @server = ModelServer.create(model_server_params)

    respond_to do |format|
      format.turbo_stream do
        if @server.errors.empty?
          render turbo_stream: turbo_stream.replace("settings_model_servers", partial: "settings/model_servers")
        else
          flash.now[:error] = @server.errors
          render turbo_stream: turbo_stream.replace(user_dom_id("notice"), partial: "shared/notice")
        end
      end
    end
  end

  private

  def update_setting(value)
    if value.to_i.to_s == value
      value = value.to_i
    elsif value.to_f.to_s == value
      value = value.to_f
    elsif %w[true false].include?(value)
      value = value == "true"
    end

    @setting.update!(value:)
  end

  def setting_params
    params.require(:setting).permit(:value)
  end

  def set_setting
    @setting = Setting.find(params[:id])
  end

  def model_server_params
    params.require(:model_server).permit(:name, :provider, :url)
  end
end
