# frozen_string_literal: true

class Views::Settings::Agents::Index < Views::Base
  FLOORS = {
    visitor: "Everyone",
    curator: "Curators and admins",
    admin: "Admins only"
  }.freeze

  def initialize(agents:, toolsets:, purpose:)
    @agents = agents
    @toolsets = toolsets
    @purpose = purpose
  end

  def view_template
    breadcrumb(["Settings", settings_path], "Agents")

    header(class: "mb-8") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Agents" }
      p(class: "mt-1 text-sm text-muted") { "Who people chat with, and what each one can do." }
    end

    agents
    toolsets
    purpose
  end

  private

  def page_title = "Agents"

  def agents
    div(class: "flex flex-col gap-3") do
      @agents.each do |agent|
        render Views::MenuCard.new(
          href: settings_agent_path(agent),
          title: agent.name,
          description: agent.toolsets.map(&:label).to_sentence.presence || "No toolsets",
          meta: agent.built_in? ? "built in" : nil
        ) { render Views::Settings::Agents::Icon.new }
      end
    end
  end

  # Hairlines, not cards: a toolset has no page of its own to lead to.
  def toolsets
    section(class: "mt-10") do
      h2(class: "text-xs font-medium uppercase tracking-wider text-faint") { "Toolsets" }
      div(class: "mt-1 divide-y divide-line") do
        @toolsets.each do |toolset|
          div(class: "flex items-start justify-between gap-4 py-4") do
            div(class: "min-w-0") do
              p(class: "text-sm font-medium text-fg") { toolset.label }
              p(class: "mt-0.5 text-xs text-faint") { toolset.description }
            end
            span(class: "shrink-0 pt-0.5 text-xs text-muted") { FLOORS.fetch(toolset.role_floor) }
          end
        end
      end
    end
  end

  def purpose
    section(class: "mt-10") do
      h2(class: "text-xs font-medium uppercase tracking-wider text-faint") { "Every agent" }
      form(action: settings_purpose_path, method: "post", class: "mt-4 flex flex-col gap-4") do
        input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
        input(type: "hidden", name: "_method", value: "patch")

        div do
          label(class: "block text-sm font-medium text-fg", for: "purpose") { Setting.label("chat.instance_purpose") }
          p(class: "mt-0.5 mb-2 text-xs text-faint") { Setting.description("chat.instance_purpose") }
          textarea(
            id: "purpose", name: "purpose", rows: "5",
            placeholder: "e.g. You are Atlas, answering questions for Acme's support team. Be concise.",
            data: { controller: "autogrow", action: "input->autogrow#resize" },
            class: "w-full resize-none overflow-y-hidden rounded border border-line bg-void/60 px-3 py-2 " \
              "text-sm text-fg placeholder:text-faint outline-none focus:border-accent transition-colors"
          ) { @purpose }
        end

        div do
          button(type: "submit", class: button_class(:solid)) { "Save" }
        end
      end
    end
  end
end
