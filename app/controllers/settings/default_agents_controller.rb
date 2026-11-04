module Settings
  class DefaultAgentsController < ApplicationController
    require_role :admin

    def update
      agent = Agent.find_by(slug: params[:agent])
      unless agent&.default_eligible?
        return redirect_to settings_agents_path, alert: "Only an agent everyone can use can be the default."
      end

      Setting["chat.default_agent"] = agent.slug
      redirect_to settings_agents_path, notice: "New chats now go to #{agent.name}."
    end
  end
end
