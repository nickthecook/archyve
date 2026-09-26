module Settings
  # The system prompt every chat uses. Currently just the instance purpose,
  # appended to Archyve's own instructions — see Chat::Instructions.
  class PromptsController < ApplicationController
    require_role :admin

    def show
      render Views::Settings::Prompts::Show.new(purpose: Setting.chat_instance_purpose)
    end

    def update
      Setting["chat.instance_purpose"] = params[:purpose].to_s.strip
      redirect_to settings_path, notice: "Saved."
    end
  end
end
