module Settings
  class AgentsController < ApplicationController
    require_role :admin

    def index
      render Views::Settings::Agents::Index.new(
        agents: Agent.order(:name), toolsets: Toolsets.all, purpose: Setting.chat_instance_purpose
      )
    end

    def show
      render Views::Settings::Agents::Show.new(agent: Agent.find_by!(slug: params[:id]))
    end
  end
end
