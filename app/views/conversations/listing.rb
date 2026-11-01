# frozen_string_literal: true

# A listing, in the transcript, where it happened.
#
# Same shell as the search and read panels beside it — collapsed, tally in the
# summary row — because it is the same kind of event: the model stopped talking
# and went to the archive. What differs is that nothing in here is a passage, so
# there are no cards to expand into and nothing carries a citation handle.
# Document rows open the document instead.
#
# Three states, and they must not look alike: running, listed, and refused.
class Views::Conversations::Listing < Components::Base
  ROW = "block rounded border border-line bg-ink/60 px-3.5 py-3"
  # Hover on the whole row, accent on the name: the app's vocabulary for a row
  # that opens the thing it names. A *named* group, because the enclosing
  # details already carries `group` for its chevron.
  OPENS = "group/row hover:border-line-2 hover:bg-ink transition-colors"

  def initialize(segment:)
    @segment = segment
  end

  def view_template
    details(class: "group rounded-lg border border-line bg-ink/40", open: false) do
      summary(class: "flex cursor-pointer list-none items-center gap-3 px-4 py-3") do
        tile
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

  # Nothing is recorded until the listing returns, so an absent `listing` is one
  # still running rather than one that listed nothing.
  def running? = @segment.listing.blank?

  def tile
    span(class: "grid h-7 w-7 shrink-0 place-items-center rounded #{tile_class}") do
      running? ? render(Views::Spinner.new(size: 15)) : rows_icon
    end
  end

  def tile_class
    return "bg-line/40 text-faint" if @segment.listing_refused? || (!running? && @segment.listed_entries.empty?)

    "bg-accent/10 text-accent"
  end

  def rows_icon
    svg(width: "14", height: "14", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", aria_hidden: "true") do |s|
      s.path(d: "M4 6h16")
      s.path(d: "M4 12h16")
      s.path(d: "M4 18h10")
    end
  end

  def chevron
    svg(class: "shrink-0 text-faint transition-transform group-open:rotate-90", width: "14", height: "14", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", aria_hidden: "true") do |s|
      s.path(d: "m9 6 6 6-6 6")
    end
  end

  def headline
    return "Looking through the archive…" if running?
    return "Couldn't list that collection" if @segment.listing_refused?
    return "Listed the collections in this chat" if @segment.listed_collections?

    "Listed #{@segment.listed_title}"
  end

  # Each count is one fact, so it breaks between facts or not at all — see the
  # note in Views::Conversations::Retrieval.
  def tally
    return if running? || @segment.listing_refused?

    (@segment.listed_collections? ? collection_tally : document_tally).tr(" ", " ")
  end

  def collection_tally
    shown = @segment.listed_entries.size
    total = @segment.listed_total.to_i
    total > shown ? "#{shown} of #{total} collections" : "#{shown} #{'collection'.pluralize(shown)}"
  end

  def document_tally
    total = @segment.listed_total.to_i
    return "#{total} #{'document'.pluralize(total)}" if @segment.listed_entries.size == total

    "#{@segment.listed_from}–#{@segment.listed_to} of #{total} documents"
  end

  def body
    div(class: "flex flex-col gap-2 border-t border-line/60 p-4") do
      next nothing if running? || @segment.listing_refused? || @segment.listed_entries.empty?

      @segment.listed_entries.each { @segment.listed_collections? ? collection_row(it) : document_row(it) }
    end
  end

  # Not a link: a collection's page is for whoever edits it, and most people
  # reading a chat can't open it.
  def collection_row(entry)
    div(class: ROW) do
      div(class: "flex items-baseline gap-3") do
        span(class: "truncate text-[0.8125rem] font-medium text-fg") { entry["name"] }
        span(class: "ml-auto shrink-0 font-mono text-[0.7rem] text-faint tabular-nums") { count_of(entry["documents"], "document") }
      end
      div(class: "mt-1 text-[0.75rem] text-faint") { fed_by(entry) }
    end
  end

  def document_row(entry)
    a(href: routes.document_path(entry["id"]), class: "#{ROW} #{OPENS}") do
      div(class: "flex items-baseline gap-3") do
        span(class: "truncate text-[0.8125rem] font-medium text-fg transition-colors group-hover/row:text-accent") { entry["title"] }
        span(class: "ml-auto shrink-0 font-mono text-[0.7rem] text-faint tabular-nums") { chunks_of(entry) }
      end
      div(class: "mt-1 text-[0.75rem] text-faint") { entry["source"] }
    end
  end

  # Route helpers off the routes module rather than the view adapter: a panel
  # renders from a broadcast as well as from a request, and a broadcast has no
  # view context for the adapter to reach through. Hit#href does the same.
  def routes = Rails.application.routes.url_helpers

  # Where the documents come from, which is half of what a listing is for.
  def fed_by(entry)
    sources = Array(entry["sources"])
    sources.any? ? "Fed by #{sources.to_sentence}" : "No source feeds this collection"
  end

  # A document with no chunks hasn't been processed, and saying "0 chunks" reads
  # as an empty document rather than one that isn't ready.
  def chunks_of(entry)
    entry["chunks"].to_i.zero? ? "not processed" : count_of(entry["chunks"], "chunk")
  end

  def count_of(count, noun) = "#{count} #{noun.pluralize(count.to_i)}".tr(" ", " ")

  # Dashed and quiet: the app's vocabulary for "not a real thing" — see
  # docs/design.md.
  def nothing
    div(class: "rounded border border-dashed border-line px-3.5 py-4 text-[0.8125rem] text-faint") do
      note
    end
  end

  # Deliberately vaguer than the reason, the way a refused read is: a slug this
  # chat isn't scoped to is refused exactly as one that never existed — see
  # Tools::ListDocuments.
  def note
    return "Looking…" if running?
    return "That collection isn't in this chat's scope." if @segment.listing_refused?
    return "This chat isn't drawing on any collections." if @segment.listed_collections?

    "Nothing in that collection is in this chat's scope."
  end
end
