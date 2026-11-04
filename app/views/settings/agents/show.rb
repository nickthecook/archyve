# frozen_string_literal: true

class Views::Settings::Agents::Show < Views::Base
  def initialize(agent:)
    @agent = agent
  end

  def view_template
    breadcrumb(["Settings", settings_path], ["Agents", settings_agents_path], @agent.name)

    header(class: "mb-8") do
      div(class: "flex items-center gap-2") do
        h1(class: "text-2xl font-semibold tracking-tight") { @agent.name }
        span(class: "rounded-full border border-line px-2 py-0.5 text-[0.7rem] text-muted") { "built in" } if @agent.built_in?
      end
      p(class: "mt-1 text-sm text-muted") { subtitle }
    end

    prompt
    toolsets
    access
  end

  private

  def page_title = @agent.name

  def subtitle
    @agent.built_in? ? "Built into Archyve, so it can't be changed." : "An agent people can chat with."
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
