module Settings
  class AgentsController < ApplicationController
    require_role :admin

    before_action :set_agent, except: [:index, :new, :create]
    before_action :refuse_built_in, only: [:edit, :update, :destroy]

    def index
      render Views::Settings::Agents::Index.new(
        agents: Agent.order(:name), toolsets: Toolsets.all, purpose: Setting.chat_instance_purpose,
        default_agent: Agent.default_chat
      )
    end

    def show
      render Views::Settings::Agents::Show.new(agent: @agent)
    end

    def new
      render_form Agent.new(toolset_keys: [Toolsets::Archive.key], access_mode: "creator_only", collection_mode: "user")
    end

    def create
      @agent = Agent.new(creator: Current.user)
      save(:created)
    end

    def edit
      render_form @agent
    end

    def update
      save(:updated)
    end

    def duplicate
      copy = @agent.duplicate(by: Current.user)
      copy.save!
      redirect_to edit_settings_agent_path(copy), notice: "Copied #{@agent.name}. Only you can use the copy until you share it."
    end

    def destroy
      if (refusal = @agent.removal_refusal)
        return redirect_to settings_agent_path(@agent), alert: "#{@agent.name} can't be removed. #{refusal}"
      end

      @agent.destroy!
      redirect_to settings_agents_path, notice: "Removed #{@agent.name}."
    end

    private

    def set_agent
      @agent = Agent.find_by!(slug: params[:id])
    end

    def refuse_built_in
      redirect_to settings_agent_path(@agent), alert: "#{@agent.name} is built in, so it can't be changed." if @agent.built_in?
    end

    # The sharing check compares against the agent as saved, so it runs before
    # anything is assigned. collection_ids= writes through at once on a saved
    # record, hence the transaction around it.
    def save(verb)
      attributes = agent_params
      collection_ids = attributes.delete(:collection_ids)
      refusal = Agents::Sharing.new(@agent, by: Current.user)
        .refusal(access_mode: attributes[:access_mode], collection_mode: attributes[:collection_mode], collection_ids:)

      @agent.assign_attributes(attributes)
      @agent.creator ||= Current.user if @agent.creator_only?
      saved = refusal.nil? && Agent.transaction do
        @agent.collection_ids = collection_ids
        @agent.save || raise(ActiveRecord::Rollback)
      end

      return redirect_to(settings_agent_path(@agent), notice: "#{verb.to_s.capitalize} #{@agent.name}.") if saved

      @agent.errors.add(:base, refusal) if refusal
      render_form @agent, collection_ids:, status: :unprocessable_content
    end

    def agent_params
      permitted = params.expect(agent: [:name, :prompt, :access_mode, :collection_mode, { toolset_keys: [], collection_ids: [] }])
      permitted[:toolset_keys] = Array(permitted[:toolset_keys]).compact_blank
      permitted[:collection_ids] = permitted[:collection_mode] == "fixed" ? Array(permitted[:collection_ids]).compact_blank : []
      permitted.to_h.symbolize_keys
    end

    def render_form(agent, collection_ids: agent.collection_ids, status: :ok)
      render Views::Settings::Agents::Form.new(
        agent:, collections: Collection.order(:name), toolsets: Toolsets.all,
        checked_collection_ids: collection_ids.map(&:to_i)
      ), status:
    end
  end
end
