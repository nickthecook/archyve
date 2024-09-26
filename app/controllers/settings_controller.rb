class SettingsController < ApplicationController
  VISIBLE_SETTINGS = %i[
    chat_model
    embedding_model
    entity_extraction_model
    summarization_model
  ].freeze

  before_action :set_setting, only: [:update]

  def index
    @settings = visible_settings
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
        redirect_to settings_path
      end
    end
  end

  private

  def update_setting(value)
    if value.to_i.to_s == value
      value = value.to_i
    elsif value.to_f.to_s == value
      value = value.to_f
    end

    @setting.update!(value:)
  end

  def visible_settings
    VISIBLE_SETTINGS.map do |key|
      Setting.find_by(key:)
    end
  end

  def setting_params
    params.require(:setting).permit(:value)
  end

  def set_setting
    @setting = Setting.find(params[:id])
  end
end
