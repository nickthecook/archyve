# frozen_string_literal: true

# A search, in the transcript, where it happened.
#
# Collapsed by default — the summary row carries the tally, which is the honest
# version of what happened: how many queries, how many chunks survived fusion,
# out of how big a pool. Expanding shows every chunk the model was given,
# including the ones it ignored, because the only way to tell a bad answer from
# bad retrieval is to see what retrieval actually returned.
#
# Three states, and they must not look alike: running, found something, and the
# two ways of finding nothing. A search that couldn't run is not an empty
# archive — see Segment.
class Views::Chat::Retrieval < Components::Base
  def initialize(segment:)
    @segment = segment
  end

  def view_template
    details(class: "group rounded-lg border border-line bg-ink/40", open: false) do
      summary(class: "flex cursor-pointer list-none items-center gap-3 px-4 py-3") do
        tile
        span(class: "text-[0.8125rem] text-fg") { headline }
        span(class: "ml-auto shrink-0 font-mono text-[0.7rem] text-faint tabular-nums") { tally }
        chevron
      end
      body
    end
  end

  private

  def running? = !@segment.failed? && @segment.candidate_count.nil?

  def tile
    span(class: "grid h-7 w-7 shrink-0 place-items-center rounded #{tile_class}") do
      running? ? render(Views::Spinner.new(size: 15)) : magnifier
    end
  end

  def tile_class
    return "bg-red-500/15 text-red-300" if @segment.failed?
    return "bg-line/40 text-faint" if @segment.hits.empty?

    "bg-accent/10 text-accent"
  end

  def magnifier
    svg(width: "14", height: "14", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", aria_hidden: "true") do |s|
      s.circle(cx: "11", cy: "11", r: "7")
      s.path(d: "m20 20-3.5-3.5")
    end
  end

  def chevron
    svg(class: "shrink-0 text-faint transition-transform group-open:rotate-90", width: "14", height: "14", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", aria_hidden: "true") do |s|
      s.path(d: "m9 6 6 6-6 6")
    end
  end

  def headline
    return "Searching the archive…" if running?
    return "Couldn't search the archive" if @segment.failed?
    return "Searched the archive — no matches" if @segment.hits.empty?

    "Searched the archive"
  end

  # While it runs, the queries are known and the counts aren't — so the row
  # fills in rather than jumping when results land.
  def tally
    count = Array(@segment.queries).size
    return "#{count} #{'query'.pluralize(count)}" if running? || @segment.failed?

    "#{count} #{'query'.pluralize(count)} · #{chunk_tally} · #{document_tally}"
  end

  def chunk_tally
    shown = @segment.hits.size
    pool = @segment.candidate_count.to_i
    pool > shown ? "#{shown} of #{pool} chunks" : "#{shown} #{'chunk'.pluralize(shown)}"
  end

  def document_tally
    count = @segment.hits.map(&:document_title).uniq.size
    "#{count} #{'document'.pluralize(count)}"
  end

  def body
    div(class: "flex flex-col gap-3 border-t border-line/60 p-4") do
      queries
      @segment.hits.any? ? hits : nothing
    end
  end

  def queries
    div(class: "flex flex-wrap items-center gap-1.5") do
      span(class: "mr-1 text-[0.7rem] uppercase tracking-[0.12em] text-faint") { "Queries" }
      Array(@segment.queries).each do |query|
        span(class: "rounded-full border border-dashed border-line-2 px-2.5 py-0.5 font-mono text-[0.7rem] text-muted") { query }
      end
    end
  end

  def hits
    div(class: "flex flex-col gap-2") { @segment.hits.each { hit_card(it) } }
  end

  def hit_card(hit)
    div(class: "rounded border border-line bg-ink/60 px-3.5 py-3") do
      div(class: "mb-1 flex items-baseline gap-3") do
        span(class: "shrink-0 font-mono text-[0.7rem] text-accent tabular-nums") { hit.handle.to_s }
        span(class: "truncate text-[0.8125rem] font-medium text-fg") { hit.title }
        # Quiet, not accent: the list is ordered by fused score, so this
        # percentage is a quality reading rather than the sort key.
        span(class: "ml-auto shrink-0 font-mono text-[0.7rem] text-faint tabular-nums") { "#{hit.similarity}%" }
      end
      if hit.heading_path.present?
        span(class: "mb-1.5 block pl-[1.9rem] text-[0.7rem] text-faint") { hit.heading_path }
      end
      p(class: "pl-[1.9rem] text-[0.8125rem] leading-relaxed text-muted") { hit.snippet }
    end
  end

  # Dashed and quiet: the app's vocabulary for "not a real thing" — see
  # docs/design.md.
  def nothing
    div(class: "rounded border border-dashed border-line px-3.5 py-4 text-[0.8125rem] text-faint") do
      @segment.failed? ? failure_note : "Nothing in this chat's scope matched."
    end
  end

  def failure_note
    if @segment.failure_kind == "not_configured"
      "No embedding model is configured, so the archive can't be searched."
    else
      "The embedding server didn't respond, so this answer isn't drawing on your archive."
    end
  end
end
