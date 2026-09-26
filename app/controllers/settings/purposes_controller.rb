module Settings
  # What this Archyve instance is for, appended to the system prompt on every
  # chat turn. One value per instance, stored via Setting rather than a record.
  class PurposesController < ApplicationController
    require_role :admin

    def show
      render Views::Settings::Purposes::Show.new(purpose: Setting.chat_instance_purpose)
    end

    def update
      Setting["chat.instance_purpose"] = params[:purpose].to_s.strip
      redirect_to settings_path, notice: "Saved."
    end
  end
end
