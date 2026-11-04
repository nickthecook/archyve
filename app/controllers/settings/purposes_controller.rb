module Settings
  class PurposesController < ApplicationController
    require_role :admin

    def update
      Setting["chat.instance_purpose"] = params[:purpose].to_s.strip
      redirect_to settings_agents_path, notice: "Saved."
    end
  end
end
