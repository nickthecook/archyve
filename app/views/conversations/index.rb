# frozen_string_literal: true

# The way into chat: pick what to draw on, ask the first question.
#
# Starting a chat and configuring one are the same act, because the scope is
# fixed once the conversation exists — there is nothing to set up afterwards,
# so there is no setup screen. Past conversations sit below the rule as this
# page's content.
class Views::Conversations::Index < Views::Base
  def initialize(conversations:, agent:, collections:, agents: [], models: [], model: nil, scope: nil, unavailable: nil)
    @conversations = conversations
    @agents = agents
    @agent = agent
    @collections = collections
    @models = models
    @model = model
    @scope = scope
    @unavailable = unavailable
  end

  def view_template
    heading
    unavailable_panel if @unavailable
    composer
    render Views::Rule.new
    @conversations.any? ? list : empty
  end

  private

  def page_title = "Chat"

  def heading
    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Chat" }
      p(class: "mt-1 text-sm text-muted") do
        "Ask your archive a question. Retrieval runs as a tool the model calls, and every answer shows what it read."
      end
    end
  end

  def unavailable_panel
    div(class: "mb-6 rounded border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-300") { @unavailable }
  end

  def composer
    agent_picker if @agents.size > 1
    render Views::Conversations::Composer.new(
      agent: @agent, models: @models, model: @model, collections: @collections, scope: @scope,
      unavailable: @unavailable, placeholder: (Brand.current.chat_placeholder if @agent.narrowable?)
    )
  end

  # Links rather than a select inside the form: the composer below differs by
  # agent (a fixed set has no collection picker), so choosing one reloads it.
  def agent_picker
    nav(aria_label: "Agent", class: "mb-3 flex flex-wrap items-center gap-2") do
      span(class: "text-[0.7rem] uppercase tracking-[0.12em] text-faint") { "Ask" }
      @agents.each do |agent|
        selected = agent == @agent
        a(
          href: conversations_path(agent: agent.slug), aria_current: (selected ? "true" : nil),
          class: "rounded-full border px-2.5 py-1 text-xs transition-colors " \
                 "#{selected ? 'border-line-2 bg-ink text-fg' : 'border-line text-muted hover:border-line-2 hover:text-fg'}"
        ) { agent.name }
      end
    end
  end

  def list
    h2(class: "mb-3 text-xs font-semibold uppercase tracking-[0.18em] text-muted") { "Earlier" }
    div(class: "space-y-2") { @conversations.each { row(it) } }
  end

  def row(conversation)
    div(class: "flex items-center gap-4 rounded-lg border border-line bg-ink/40 px-4 py-3 hover:border-line-2 transition-colors") do
      a(href: conversation_path(conversation), class: "min-w-0 flex-1") do
        span(class: "block truncate text-sm text-fg") { conversation.title.presence || "Untitled chat" }
        span(class: "mt-0.5 block text-xs text-faint") do
          "#{conversation.subject_label} · #{time_ago_in_words(conversation.updated_at)} ago"
        end
      end
      delete_button(conversation)
    end
  end

  def delete_button(conversation)
    form(action: conversation_path(conversation), method: "post", class: "shrink-0") do
      input(type: "hidden", name: "_method", value: "delete")
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(
        type: "submit", data: { turbo_confirm: "Delete this conversation?" },
        class: "rounded border border-line px-2.5 py-1 text-xs text-faint hover:text-red-300 hover:border-red-400/40 transition-colors"
      ) { "Delete" }
    end
  end

  def empty
    div(class: "rounded-lg border border-dashed border-line px-4 py-12 text-center") do
      p(class: "text-sm text-muted") { "No conversations yet." }
    end
  end
end
