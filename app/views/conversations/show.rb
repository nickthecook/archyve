# frozen_string_literal: true

# One conversation: what it's drawing on, the transcript, and the box to ask
# the next thing.
class Views::Conversations::Show < Views::Base
  include Phlex::Rails::Helpers::TurboStreamFrom

  def initialize(conversation:, messages:, unavailable: nil)
    @conversation = conversation
    @messages = messages
    @unavailable = unavailable
  end

  def view_template
    doorway
    hr(class: "mb-8 border-line")
    scope_banner
    # Assistant turns arrive here as they are produced — Chat::Turn broadcasts a
    # replace of each one as the model streams, searches, and streams again.
    turbo_stream_from(@conversation)
    thread
    composer
  end

  private

  def page_title = @conversation.title.presence || "Chat"

  def doorway
    a(
      href: conversations_path,
      class: "group mb-8 flex items-center gap-4 rounded-lg border border-line border-l-2 border-l-accent " \
             "bg-ink/60 px-5 py-4 hover:bg-ink transition-colors"
    ) do
      span(class: "grid h-9 w-9 shrink-0 place-items-center rounded bg-accent/10 text-accent") do
        svg(width: "18", height: "18", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "1.6", aria_hidden: "true") do |s|
          s.path(d: "M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z")
        end
      end
      span(class: "min-w-0 flex-1") do
        span(class: "block text-sm text-fg") { "All conversations" }
        span(class: "block text-xs text-faint") { "Start another, or pick up an earlier one" }
      end
      svg(class: "shrink-0 text-faint transition-transform group-hover:translate-x-0.5", width: "16", height: "16", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", aria_hidden: "true") do |s|
        s.path(d: "m9 6 6 6-6 6")
      end
    end
  end

  # Stated here as well as in the composer chip and the model's instructions.
  # It belongs to the conversation rather than to any one message, and the only
  # way to change it is a new chat — so the banner says both.
  def scope_banner
    div(class: "mb-8 flex flex-wrap items-center gap-3 rounded-lg border border-line border-l-2 border-l-accent bg-ink/60 px-4 py-3") do
      span(class: "text-[0.7rem] uppercase tracking-[0.12em] text-faint") { "Drawing on" }
      span(class: "text-sm text-fg") { @conversation.scope_label }
      span(class: "ml-auto text-xs text-faint") do
        plain "Fixed for this chat — "
        a(href: conversations_path, class: "text-muted underline decoration-line-2 underline-offset-4 hover:text-fg") { "start a new one" }
        plain " to change it"
      end
    end
  end

  def thread
    div(id: Views::Conversations::Message.thread_dom_id(@conversation), class: "flex flex-col gap-10") do
      @messages.each { render Views::Conversations::Message.new(message: it) }
    end
  end

  def composer
    form(action: conversation_messages_path(@conversation), method: "post", class: "mt-10 flex flex-col gap-3 rounded-lg border border-line-2 bg-ink/60 p-4") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      textarea(
        name: "message", rows: "2", autofocus: true,
        placeholder: "Ask about #{@conversation.scope_label}…",
        class: "w-full resize-y bg-transparent text-[0.95rem] text-fg placeholder:text-faint outline-none"
      )
      div(class: "flex items-center gap-3") do
        span(class: "inline-flex items-center gap-1.5 rounded-full border border-line px-2.5 py-1 text-xs text-muted") do
          span(class: "h-1.5 w-1.5 rounded-full bg-accent")
          plain @conversation.scope_label
        end
        button(
          type: "submit", disabled: @unavailable.present?,
          class: "ml-auto rounded bg-accent px-4 py-2 text-sm font-semibold text-void hover:bg-accent-dim transition-colors"
        ) { "Send" }
      end
    end
  end
end
