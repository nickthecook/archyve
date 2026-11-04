module Settings
  # Who may use a granted agent. Built-ins are open to everyone and locked, so
  # they have no people page.
  class AgentUsersController < ApplicationController
    require_role :admin

    before_action :set_agent

    def index
      render Views::Settings::Agents::People.new(
        agent: @agent,
        grants: @agent.agent_users.includes(:user).joins(:user).order("users.email_address"),
        candidates: User.where.not(role: :admin).where.not(id: @agent.agent_users.select(:user_id)).order(:email_address)
      )
    end

    def create
      grant = @agent.agent_users.new(user_id: params[:user_id], access: params[:access])

      if grant.save
        redirect_to settings_agent_people_path(@agent), notice: "#{grant.user.email_address} can now use #{@agent.name}."
      else
        redirect_to settings_agent_people_path(@agent), alert: grant.errors.full_messages.to_sentence
      end
    end

    def update
      grant = @agent.agent_users.find(params[:id])

      if grant.update(access: params[:access])
        redirect_to settings_agent_people_path(@agent), notice: "Updated #{grant.user.email_address}."
      else
        redirect_to settings_agent_people_path(@agent), alert: grant.errors.full_messages.to_sentence
      end
    end

    def destroy
      grant = @agent.agent_users.find(params[:id])
      grant.destroy
      redirect_to settings_agent_people_path(@agent), notice: "#{grant.user.email_address} can no longer use #{@agent.name}."
    end

    private

    def set_agent
      @agent = Agent.where(built_in: false).find_by!(slug: params[:agent_id])
    end
  end
end
