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
    back_link
    scope_banner
    # Assistant turns arrive here as they are produced — Chat::Turn broadcasts a
    # replace of each one as the model streams, searches, and streams again.
    turbo_stream_from(@conversation)
    thread
    composer
  end

  private

  def page_title = @conversation.title.presence || "Chat"

  def back_link
    a(href: conversations_path, class: "text-sm text-muted hover:text-fg transition-colors") { "← All chats" }
  end

  # Stated here as well as in the composer chip and the model's instructions.
  # It belongs to the conversation rather than to any one message, and the only
  # way to change it is a new chat — so the banner says both.
  def scope_banner
    div(class: "mt-3 mb-8 flex flex-wrap items-center gap-3 rounded-lg border border-line border-l-2 border-l-accent bg-ink/60 px-4 py-3") do
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
    form(
      action: conversation_messages_path(@conversation), method: "post",
      data: {
        controller: "composer",
        action: "keydown.ctrl+enter@document->composer#submit keydown.meta+enter@document->composer#submit"
      },
      class: "mt-10 flex flex-col gap-3 rounded-lg border border-line-2 bg-ink/60 p-4"
    ) do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      textarea(
        name: "message", rows: "2", autofocus: true, autocomplete: "off",
        placeholder: "Ask about #{@conversation.scope_label}…",
        data: { composer_target: "field" },
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
