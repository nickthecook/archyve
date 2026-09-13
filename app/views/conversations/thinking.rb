# frozen_string_literal: true

# The model's reasoning, in the transcript, where it happened.
#
# Collapsed by default and deliberately quieter than a retrieval panel: this is
# working-out, not evidence. It gets the same disclosure vocabulary so the two
# read as the same kind of aside, but no accent — see docs/design.md on the
# accent ladder, where a secondary thing stays line/muted.
#
# Worth showing at all because a reasoning model's analysis is the only place
# some failures are visible: a reply that argues itself out of an answer, or one
# whose whole text arrives on the analysis channel, is otherwise a blank turn.
class Views::Conversations::Thinking < Components::Base
  def initialize(segment:)
    @segment = segment
  end

  def view_template
    return if @segment.content.blank?

    details(class: "group rounded-lg border border-line bg-ink/20", open: false) do
      summary(class: "flex cursor-pointer list-none items-center gap-3 px-4 py-2.5") do
        tile
        span(class: "text-[0.8125rem] text-muted") { "Thought about this" }
        span(class: "ml-auto shrink-0 font-mono text-[0.7rem] text-faint tabular-nums") { tally }
        chevron
      end
      body
    end
  end

  private

  def tile
    span(class: "grid h-7 w-7 shrink-0 place-items-center rounded bg-line/40 text-faint") do
      svg(width: "14", height: "14", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", aria_hidden: "true") do |s|
        s.path(d: "M12 3a6 6 0 0 0-3.6 10.8c.5.4.8 1 .8 1.6v.6h5.6v-.6c0-.6.3-1.2.8-1.6A6 6 0 0 0 12 3z")
        s.path(d: "M10 19h4")
      end
    end
  end

  # Words rather than tokens: the number is only here to say how much working-out
  # is behind the row, and tokens are a number we'd be guessing at.
  def tally
    count = @segment.content.to_s.split.size
    "#{count} #{'word'.pluralize(count)}"
  end

  def chevron
    svg(class: "shrink-0 text-faint transition-transform group-open:rotate-90", width: "14", height: "14", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", aria_hidden: "true") do |s|
      s.path(d: "m9 6 6 6-6 6")
    end
  end

  # Plain text, not the citation renderer: handles in the working-out point at
  # results the model was still deciding how to use, and rendering them as live
  # citations would promise more than the reasoning does.
  def body
    div(class: "border-t border-line/60 p-4 text-[0.8125rem] leading-relaxed text-faint whitespace-pre-wrap") do
      @segment.content
    end
  end
end
