# frozen_string_literal: true

class Views::Settings::Agents::Show < Views::Base
  def initialize(agent:)
    @agent = agent
  end

  def view_template
    breadcrumb(["Settings", settings_path], ["Agents", settings_agents_path], @agent.name)

    header(class: "mb-8 flex flex-wrap items-start justify-between gap-x-4 gap-y-3") do
      div(class: "min-w-0") do
        div(class: "flex items-center gap-2") do
          h1(class: "text-2xl font-semibold tracking-tight") { @agent.name }
          span(class: "rounded-full border border-line px-2 py-0.5 text-[0.7rem] text-muted") { "built in" } if @agent.built_in?
        end
        p(class: "mt-1 text-sm text-muted") { subtitle }
      end
      div(class: "flex shrink-0 items-center gap-2") do
        a(href: edit_settings_agent_path(@agent), class: button_class(:quiet)) { "Edit" } unless @agent.built_in?
        duplicate_button
        remove_button unless @agent.built_in?
      end
    end

    prompt
    toolsets
    access
  end

  private

  def page_title = @agent.name

  def subtitle
    return "Built into Archyve, so it can't be changed. Duplicate it to make one you can." if @agent.built_in?
    return "Created by: #{@agent.creator.email_address}" if @agent.creator

    "Its creator's account has been deleted."
  end

  def duplicate_button
    form(action: duplicate_settings_agent_path(@agent), method: "post", class: "inline") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(type: "submit", class: button_class(:quiet)) { "Duplicate" }
    end
  end

  # Disabled rather than hidden, with the reason on hover, as on an inference server.
  def remove_button
    if (refusal = @agent.removal_refusal)
      return span(class: button_class(:danger, "opacity-40"), aria_disabled: "true", title: refusal) { "Delete" }
    end

    form(action: settings_agent_path(@agent), method: "post", class: "inline",
      data: { turbo_confirm: "Delete “#{@agent.name}”? Its grants and collection choices go with it." }) do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "delete")
      button(type: "submit", class: button_class(:danger)) { "Delete" }
    end
  end

  def prompt
    section_titled("Prompt") do
      if @agent.prompt.present?
        p(class: "whitespace-pre-wrap break-words rounded-lg border border-line bg-ink/40 px-5 py-4 text-sm text-muted") do
          @agent.prompt
        end
      else
        p(class: "rounded-lg border border-dashed border-line px-5 py-4 text-sm text-faint") { "No prompt." }
      end
    end
  end

  def toolsets
    section_titled("Toolsets") do
      div(class: "divide-y divide-line") do
        @agent.toolsets.each do |toolset|
          div(class: "py-3") do
            p(class: "text-sm font-medium text-fg") { toolset.label }
            p(class: "mt-0.5 text-xs text-faint") { toolset.description }
          end
        end
      end
    end
  end

  def access
    section_titled("Who can chat with it") do
      p(class: "text-sm text-muted") { who }
      people_link unless @agent.built_in?
    end
    draws_on if @agent.searches_archive?
  end

  def who
    floor = Views::Settings::Agents::Index::FLOORS.fetch(@agent.role_floor)
    return floor if @agent.everyone?
    return "People granted access" + (@agent.role_floor == :visitor ? "" : " — #{floor.downcase}") if @agent.granted?
    return "Only #{@agent.creator.email_address}" if @agent.creator

    "Nobody: the account that created it was deleted"
  end

  def people_link
    count = @agent.agent_users.count
    a(href: settings_agent_people_path(@agent), class: "mt-2 inline-block text-sm text-accent hover:text-accent-dim transition-colors") do
      count.zero? ? "Grant people access" : "#{count} #{'person'.pluralize(count)} granted access"
    end
  end

  def draws_on
    section_titled("Draws on") do
      p(class: "text-sm text-muted") do
        next "Whatever the person chatting can read, narrowed when they start the chat" if @agent.user_collections?

        @agent.collections.order(:name).map(&:name).to_sentence.presence || "No collections"
      end
    end
  end

  def section_titled(title, &)
    section(class: "mb-8") do
      h2(class: "mb-2 text-xs font-medium uppercase tracking-wider text-faint") { title }
      yield
    end
  end
end
