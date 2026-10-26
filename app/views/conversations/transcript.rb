# frozen_string_literal: true

# What a conversation is drawing on, and everything said in it — the part of a
# chat any reader sees, whether or not they may add to it.
class Views::Conversations::Transcript < Components::Base
  def initialize(conversation:, messages:, editable:)
    @conversation = conversation
    @messages = messages
    @editable = editable
  end

  def view_template
    scope_banner
    thread
  end

  private

  # Stated here as well as in the composer chip and the model's instructions.
  # It belongs to the conversation rather than to any one message, and the only
  # way to change it is a new chat — so the banner says both.
  def scope_banner
    div(class: "mb-8 flex flex-wrap items-center gap-3 rounded-lg border border-line border-l-2 bg-ink/60 px-4 py-3") do
      span(class: "text-[0.7rem] uppercase tracking-[0.12em] text-faint") { "Drawing on" }
      span(class: "text-sm text-fg") { drawing_on }
      fixed_note if @editable
    end
  end

  def fixed_note
    span(class: "ml-auto text-xs text-faint") do
      plain "Fixed for this chat — "
      a(href: conversations_path, class: "text-muted underline decoration-line-2 underline-offset-4 hover:text-fg") { "start a new one" }
      plain " to change it"
    end
  end

  # A chat with no collections isn't drawing on anything, and saying "no
  # collections" in a box labelled "Drawing on" reads as a fault rather than as
  # the choice it was.
  def drawing_on
    @conversation.searches_archive? ? @conversation.scope_label : "nothing — this chat doesn't search your archive"
  end

  # The transcript, and the fallback for when the cable isn't carrying it.
  #
  # Streaming is the mechanism here — this poll exists for the cases it can't
  # cover: a subscription that never came up, a connection that dropped
  # mid-answer, or a second tab on the same conversation, which is sent nothing
  # at all because the question was recorded in another tab's request. `idle`
  # keeps it out of the way while broadcasts are arriving; see the note on
  # Components::Base#progress_data.
  def thread
    div(
      id: Views::Conversations::Message.thread_dom_id(@conversation),
      class: "flex flex-col gap-10",
      data: progress_data(
        terminal: @messages.none?(&:in_progress?), idle: 2000,
        # The meter sits outside this region but goes stale with it, and its own
        # broadcast is lost to exactly the failures this poll covers — a cable
        # that never came up, a second tab. Swapped from the same response.
        also: [Views::Conversations::ContextMeter.dom_id(@conversation)]
      )
    ) do
      @messages.each { render Views::Conversations::Message.new(message: it, editable: @editable) }
    end
  end
end
