# frozen_string_literal: true

# One turn of a conversation, from either side.
#
# The broadcast target: Chat::Turn re-renders this and replaces it over the
# cable as the model streams, searches, and streams again. Kept helper-free —
# dom_id computed directly, no route helpers on the streaming path — so it can
# be rendered to a string outside a request, the same way
# Views::Documents::Detail is.
class Views::Conversations::Message < Components::Base
  def self.dom_id(message) = ActionView::RecordIdentifier.dom_id(message)

  # The container the whole transcript lives in. Nothing broadcasts to it —
  # turns are opened by Chat::Ask in the request, so every stream is a replace
  # of a turn already on the page — but it is the region the page re-fetches
  # and swaps when the cable isn't delivering, so it needs a stable id.
  def self.thread_dom_id(conversation) = ActionView::RecordIdentifier.dom_id(conversation, :thread)

  def initialize(message:)
    @message = message
  end

  def view_template
    div(id: self.class.dom_id(@message), class: wrapper_class) do
      @message.user? ? from_user : from_assistant
    end
  end

  private

  # A person's message is contained; the model's answer flows on the page.
  # Weight from being a different kind of thing rather than a louder card —
  # see docs/design.md on the box costume.
  #
  # Both carry scroll-mt because this element is an anchor target:
  # MessagesController sends the asker back to their own question, and without
  # it the question lands flush against the top edge of the viewport. Written
  # out in each branch rather than interpolated in — Tailwind scans these files
  # as text, and a class name it only ever sees in halves doesn't exist.
  def wrapper_class
    return "scroll-mt-6 flex justify-end" if @message.user?

    "scroll-mt-6 flex flex-col gap-4 max-w-[68ch]"
  end

  def from_user
    div(class: "max-w-[68ch] rounded-lg border border-line bg-ink/40 px-4 py-3 text-[0.95rem] text-fg whitespace-pre-wrap") do
      @message.text
    end
  end

  def from_assistant
    @message.segments.each { |segment| render Views::Conversations::Segment.new(segment:) }
    broken if @message.failed?
    waiting
    attribution
  end

  # Which model wrote this. Quiet and per-turn rather than stated once at the
  # top, because the model can be switched mid-conversation — and when it has
  # been, "which one said that?" is exactly the question the transcript should
  # already have answered. Absent on an old turn whose model row has since been
  # removed, which is honest: we no longer know what it was called.
  #
  # How fast it ran goes here too, for the same reason: the interesting question
  # about a rate is which model produced it, so the two belong on one line.
  def attribution
    return if @message.in_progress? || @message.inference_model.nil?

    div(class: "font-mono text-[0.7rem] text-faint tabular-nums") do
      plain @message.inference_model.label
      render Views::Conversations::Rate.new(@message.tokens_per_second)
    end
  end

  # The gaps where the model is working and the page has nothing to show: before
  # the first token, and — the long one — after a search, while it reads six
  # chunks before saying anything. Once prose is streaming the text is its own
  # evidence of progress, so nothing is rendered then. See Message#waiting_on.
  def waiting
    label = @message.waiting_on
    return if label.nil?

    div(class: "flex items-center gap-2.5 text-faint") do
      span(class: "grid h-7 w-7 place-items-center rounded bg-accent/10 text-accent") do
        render Views::Spinner.new(size: 15)
      end
      span(class: "text-xs") { label }
    end
  end

  # A transport failure, not something the model said — see Message#error.
  def broken
    div(class: "flex items-center gap-3 rounded-lg border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-300") do
      span(class: "grid h-7 w-7 shrink-0 place-items-center rounded bg-red-500/15") do
        svg(width: "14", height: "14", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", aria_hidden: "true") do |s|
          s.path(d: "M12 8v5")
          s.path(d: "M12 16.5v.5")
          s.path(d: "M10.3 3.9 2.4 18a1.9 1.9 0 0 0 1.7 2.9h15.8a1.9 1.9 0 0 0 1.7-2.9L13.7 3.9a1.9 1.9 0 0 0-3.4 0z")
        end
      end
      span { @message.error }
    end
  end
end
