# frozen_string_literal: true

# One turn of a conversation, from either side.
#
# The broadcast target: Chat::Turn re-renders this and replaces it over the
# cable as the model streams, searches, and streams again. Kept helper-free —
# dom_id computed directly, no route helpers on the streaming path — so it can
# be rendered to a string outside a request, the same way
# Views::Documents::Detail is.
class Views::Chat::Turn < Components::Base
  def self.dom_id(message) = ActionView::RecordIdentifier.dom_id(message)

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
  def wrapper_class
    @message.user? ? "flex justify-end" : "flex flex-col gap-4 max-w-[68ch]"
  end

  def from_user
    div(class: "max-w-[42ch] rounded-lg border border-line bg-ink/40 px-4 py-3 text-[0.95rem] text-fg whitespace-pre-wrap") do
      @message.text
    end
  end

  def from_assistant
    @message.segments.each { |segment| render_segment(segment) }
    broken if @message.failed?
    thinking if empty?
  end

  def render_segment(segment)
    segment.text? ? prose(segment) : render(Views::Chat::Retrieval.new(segment:))
  end

  def prose(segment)
    return if segment.content.blank?

    div(class: "text-[0.95rem] leading-relaxed text-muted whitespace-pre-wrap") do
      render Views::Chat::Cited.new(segment:)
    end
  end

  # The gap between "the job started" and the model's first token. Without it
  # the turn is an empty box and the page looks stuck.
  def thinking
    div(class: "flex items-center gap-2.5 text-faint") do
      span(class: "grid h-7 w-7 place-items-center rounded bg-accent/10 text-accent") do
        render Views::Spinner.new(size: 15)
      end
      span(class: "text-xs") { "Thinking…" }
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

  def empty?
    !@message.failed? && @message.segments.none? { it.retrieval? || it.content.present? }
  end
end
