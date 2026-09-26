# frozen_string_literal: true

# A read, in the transcript, where it happened.
#
# Same shell as the search panel beside it — collapsed, with the tally in the
# summary row — because they are the same kind of event: the model stopped
# talking and went to the archive. What differs is what there is to say about
# it. A search is judged by what it dredged up out of how big a pool; a read is
# judged by whether it looked at the right part of the right document, so the
# tally is a range rather than a count.
#
# Three states, and they must not look alike: running, read, and refused. A
# refused read is not an empty document — see Retrieval::Reading.
class Views::Conversations::Reading < Components::Base
  def initialize(segment:)
    @segment = segment
  end

  def view_template
    details(class: "group rounded-lg border border-line bg-ink/40", open: false) do
      summary(class: "flex cursor-pointer list-none items-center gap-3 px-4 py-3") do
        tile
        # Wraps rather than truncates, and the range never breaks across lines:
        # see the note in Views::Conversations::Retrieval, which this mirrors.
        div(class: "flex min-w-0 flex-1 flex-wrap items-baseline gap-x-3") do
          span(class: "min-w-0 text-[0.8125rem] text-fg") { headline }
          span(class: "ml-auto min-w-0 text-right font-mono text-[0.7rem] text-faint tabular-nums") { tally }
        end
        chevron
      end
      body
    end
  end

  private

  # Nothing is recorded until the read returns, so an absent `reading` is a read
  # still running rather than one that read nothing.
  def running? = @segment.reading.blank?

  def tile
    span(class: "grid h-7 w-7 shrink-0 place-items-center rounded #{tile_class}") do
      running? ? render(Views::Spinner.new(size: 15)) : pages
    end
  end

  def tile_class
    return "bg-line/40 text-faint" if @segment.refused?

    "bg-accent/10 text-accent"
  end

  def pages
    svg(width: "14", height: "14", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", aria_hidden: "true") do |s|
      s.path(d: "M4 4h9a3 3 0 0 1 3 3v13a2 2 0 0 0-2-2H4z")
      s.path(d: "M20 4h-1a3 3 0 0 0-3 3v13a2 2 0 0 1 2-2h2z")
    end
  end

  def chevron
    svg(class: "shrink-0 text-faint transition-transform group-open:rotate-90", width: "14", height: "14", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", aria_hidden: "true") do |s|
      s.path(d: "m9 6 6 6-6 6")
    end
  end

  def headline
    return "Reading a document…" if running?
    return "Couldn't read that document" if @segment.refused?

    "Read #{@segment.read_title}"
  end

  def tally
    return if running? || @segment.refused?

    @segment.range.tr(" ", " ")
  end

  def body
    div(class: "flex flex-col gap-2 border-t border-line/60 p-4") do
      @segment.hits.any? ? hits : nothing
    end
  end

  def hits
    @segment.hits.each { render Views::Conversations::HitCard.new(hit: it) }
  end

  # Dashed and quiet: the app's vocabulary for "not a real thing" — see
  # docs/design.md.
  def nothing
    div(class: "rounded border border-dashed border-line px-3.5 py-4 text-[0.8125rem] text-faint") do
      running? ? "Fetching the document…" : refusal_note
    end
  end

  # Deliberately vaguer than the reason: the tool refuses an unreadable id the
  # same way it refuses one that never existed, and a panel that told them apart
  # would undo that — see Tools::Read.
  def refusal_note
    case @segment.reading&.dig("refusal")
    when "not_processed" then "That document hasn't finished processing, so it has no text yet."
    when "out_of_range" then "That part of the document doesn't exist."
    else "That document isn't in this chat's scope."
    end
  end
end
