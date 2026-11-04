# frozen_string_literal: true

class Views::Settings::Agents::People < Views::Base
  ACCESS = {
    "accessor" => "Chat with it",
    "editor" => "…and choose its collections",
    "manager" => "…and change everything else about it"
  }.freeze

  def initialize(agent:, grants:, candidates:)
    @agent = agent
    @grants = grants
    @candidates = candidates
  end

  def view_template
    breadcrumb(["Settings", settings_path], ["Agents", settings_agents_path], [@agent.name, settings_agent_path(@agent)], "People")

    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { "People" }
      p(class: "mt-1 text-sm text-muted") { blurb }
    end

    render Views::People::Panel.new(
      subject: @agent,
      grants: @grants,
      candidates: @candidates,
      access: ACCESS,
      create_path: settings_agent_people_path(@agent),
      member_path: ->(grant) { settings_agent_person_path(@agent, grant) }
    )
  end

  private

  def page_title = "People · #{@agent.name}"

  # Grants are kept whatever the mode, so switching back to granted restores them.
  def blurb
    return "Who can chat with “#{@agent.name}”. Only admins can change an agent for now." if @agent.granted?

    "These grants only apply when “#{@agent.name}” is set to people granted access; right now it isn't."
  end
end
