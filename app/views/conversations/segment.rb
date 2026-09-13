# frozen_string_literal: true

# One segment of a turn, in a wrapper the cable can aim at.
#
# The wrapper exists for streaming: while a turn runs, only the segment being
# written to changes, and replacing the whole message to say so re-sends every
# frozen retrieval panel above it — four fifths of the payload, ten times a
# second. Chat::Turn replaces *this* instead.
#
# Rendered by Views::Conversations::Message too, so the page and the broadcast
# emit the same markup. They have to: a Turbo replace swaps one for the other,
# and markup that differs between the two paths makes the DOM drift from what a
# reload would produce.
#
# `contents` rather than a bare div: segments are flex children of the message,
# and a wrapper that generated a box would add a gap of its own between every
# one of them. display:contents keeps the element addressable without putting it
# in the layout.
class Views::Conversations::Segment < Components::Base
  def self.dom_id(segment) = ActionView::RecordIdentifier.dom_id(segment)

  # `hits` is the handle → Hit map for resolving citations, and only the
  # streaming path passes one. Left nil, Cited works it out from the segments
  # around this one, which is right for a page render and far too expensive per
  # tick — see Chat::Turn#retrieval_finished.
  def initialize(segment:, hits: nil)
    @segment = segment
    @hits = hits
  end

  def view_template
    div(id: self.class.dom_id(@segment), class: "contents") do
      case @segment.kind.to_sym
      when :text then prose
      when :thinking then render Views::Conversations::Thinking.new(segment: @segment)
      else render Views::Conversations::Retrieval.new(segment: @segment)
      end
    end
  end

  private

  def prose
    return if @segment.content.blank?

    # `answer` is the hook for answer.css, which styles the markdown Chat::Prose
    # renders. No whitespace-pre-wrap: the HTML carries its own block layout now,
    # and pre-wrap would render the newlines *between* its tags as blank lines.
    div(class: "answer text-[0.95rem] leading-relaxed text-muted") do
      render Views::Conversations::Cited.new(segment: @segment, hits: @hits)
    end
  end
end
