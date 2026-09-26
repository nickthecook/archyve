# frozen_string_literal: true

# The Collections section home: browse every collection, search across all of
# them (scope preset to "All"), and add new ones. A collection card shows its
# name, a segmented status meter (ingestion health of its active documents), its
# source, and how many documents it holds. "Unsorted" is a derived view of
# documents with no active membership — shown apart from the real collections.
class Views::Collections::Index < Views::Base
  # Segment colours for the status meter, ordered as they stack left-to-right.
  # Shares the status vocabulary of Views::Documents::StatusBadge.
  METER = {
    "processed" => "bg-emerald-600",
    "processing" => "bg-accent",
    "pending" => "bg-line-2",
    "failed" => "bg-red-400",
    "removed" => "bg-faint"
  }.freeze

  def initialize(rows:, unsorted_count:, sources_count:)
    @rows = rows
    @unsorted_count = unsorted_count
    @sources_count = sources_count
  end

  def view_template
    heading
    sources
    search
    rule
    # The filter controller must wrap both its query input (in the toolbar) and
    # the cards it narrows (in the grid) — targets have to be descendants.
    div(data: { controller: "list-filter" }) do
      toolbar
      @rows.any? ? grid : empty_state
    end
    unsorted if @unsorted_count.positive?
  end

  private

  def page_title = "Collections"

  def heading
    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Collections" }
      p(class: "mt-1 text-sm text-muted") { "Every set of documents in the archive, and how far each has been processed." }
    end
  end

  def rule
    render Views::Rule.new
  end

  # The corridor search, scope preset to All. Scope is URL-encoded (c[]/doc); All
  # means no param, so the chip is a read-only indicator until the picker lands.
  def search
    form(action: search_path, method: "get", class: "mb-8") do
      div(class: "flex flex-wrap items-center gap-x-3 gap-y-2 rounded border border-line-2 bg-ink/60 px-4 py-3 focus-within:border-accent transition-colors") do
        search_icon
        input(
          type: "text", name: "q", placeholder: "Search across every collection",
          autocomplete: "off",
          class: "min-w-0 flex-1 bg-transparent text-fg placeholder:text-faint outline-none text-[0.95rem]"
        )
        scope_chip
      end
    end
  end

  def scope_chip
    span(
      class: "shrink-0 inline-flex items-center gap-1.5 rounded-full border border-line px-2.5 py-1 text-xs text-muted",
      title: "Search targets all collections"
    ) do
      span(class: "h-1.5 w-1.5 rounded-full bg-accent")
      plain "All collections"
    end
  end

  # Filter (narrows the list as you type) on the left; ways to add on the right.
  def toolbar
    div(class: "mb-3 flex flex-wrap items-center gap-3") do
      input(
        type: "text", placeholder: "Filter collections",
        autocomplete: "off",
        data: { list_filter_target: "query", action: "input->list-filter#filter" },
        class: "flex-1 rounded border border-line bg-ink/40 px-3 py-2 text-sm text-fg placeholder:text-faint outline-none focus:border-line-2 transition-colors"
      )
      new_collection
      a(
        href: documents_path,
        class: "shrink-0 rounded border border-line px-3 py-2 text-sm text-muted hover:text-fg hover:border-line-2 transition-colors"
      ) { "Upload" }
    end
  end

  def new_collection
    details(class: "relative shrink-0 group") do
      # Outlined, not solid: this only opens the disclosure. Solid brass is
      # reserved for the Create submit below — the action that commits.
      summary(
        class: "cursor-pointer list-none rounded border border-accent/60 bg-accent/10 px-3 py-2 " \
               "text-sm font-medium text-accent hover:bg-accent/20 hover:border-accent " \
               "group-open:bg-accent/20 group-open:border-accent transition-colors"
      ) { "New collection" }
      div(class: "absolute right-0 z-10 mt-2 w-72 rounded-lg border border-line-2 bg-ink p-3 shadow-lg") do
        form(action: collections_path, method: "post", class: "flex flex-col gap-2") do
          input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
          input(
            type: "text", name: "collection[name]", placeholder: "Collection name", required: true, autofocus: true,
            class: "w-full rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg placeholder:text-faint outline-none focus:border-accent transition-colors"
          )
          # Optional here, and editable on the collection itself: someone naming
          # a collection rarely knows yet what will end up in it.
          textarea(
            name: "collection[description]", rows: "2", placeholder: "What it is for (optional)",
            class: "w-full resize-y rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg placeholder:text-faint outline-none focus:border-accent transition-colors"
          )
          button(type: "submit", class: "self-end rounded bg-accent px-3 py-1.5 text-sm font-medium text-void hover:bg-accent-dim transition-colors") { "Create" }
        end
      end
    end
  end

  def grid
    div(
      class: "grid grid-cols-1 gap-3 sm:grid-cols-2",
      data: { list_filter_target: "list" }
    ) do
      @rows.each { |row| card(row) }
      no_matches
    end
  end

  # data-name lets the client-side filter match without a round trip.
  def card(row)
    collection = row.collection
    # A column with the meter pushed to the bottom: descriptions vary in length,
    # and a row of cards whose meters sit at different heights reads as a
    # jumble rather than as a set that can be compared at a glance.
    a(
      href: collection_path(collection),
      class: "flex h-full flex-col rounded-lg border border-line bg-ink/40 p-4 hover:border-line-2 transition-colors",
      data: { list_filter_target: "item", name: collection.name.downcase }
    ) do
      div(class: "mb-3 flex items-start justify-between gap-3") do
        span(class: "truncate text-sm font-medium text-fg") { collection.name }
        source_marker if row.source_fed
      end
      # Clamped rather than truncated: a description is a sentence or two, and
      # one line of it says less than nothing about what a collection holds.
      p(class: "mb-3 line-clamp-2 text-xs leading-relaxed text-faint") { collection.description } if collection.description.present?
      div(class: "mt-auto") do
        meter(row.status_counts, row.documents_count)
        div(class: "mt-3 flex items-center justify-between text-xs") do
          span(class: "font-mono tabular-nums text-muted") { "#{row.documents_count} #{'document'.pluralize(row.documents_count)}" }
          span(class: "text-faint") { updated(row.last_activity_at) }
        end
      end
    end
  end

  def source_marker
    span(class: "shrink-0 inline-flex items-center gap-1 text-xs text-faint", title: "Fed by a source") do
      span(class: "h-1.5 w-1.5 rounded-full bg-accent/70")
      plain "Source"
    end
  end

  # Segmented bar: one slice per status, width proportional to its share of the
  # collection's active documents. Empty collections get a hollow track.
  def meter(status_counts, total)
    div(class: "flex h-1.5 w-full overflow-hidden rounded-full bg-line/50") do
      next if total.zero?

      METER.each_key do |status|
        count = status_counts[status].to_i
        next if count.zero?

        div(
          class: "h-full #{METER[status]}",
          style: "width: #{(count.to_f / total * 100).round(2)}%",
          title: "#{count} #{status}"
        )
      end
    end
  end

  # Sources live with the content they produce rather than under Settings, so
  # the way in is here — above the rule, in the zone for links that leave this
  # page. See Views::Doorway and docs/design.md.
  def sources
    div(class: "mb-8") do
      render Views::Doorway.new(
        href: sources_path,
        title: "Sources",
        description: "Where documents come from — folders, and later object stores and wikis.",
        meta: "#{@sources_count} #{'source'.pluralize(@sources_count)}"
      ) { source_icon }
    end
  end

  # "Unsorted" is a derived view (documents with no active membership), not a
  # real collection — so it reads differently: dashed, quiet, set apart.
  def unsorted
    a(href: unsorted_path, class: "mt-6 flex items-center justify-between gap-3 rounded-lg border border-dashed border-line px-4 py-3 hover:border-line-2 transition-colors") do
      div do
        span(class: "text-sm text-muted") { "Unsorted" }
        span(class: "ml-2 text-xs text-faint") { "documents not in any collection" }
      end
      span(class: "font-mono tabular-nums text-xs text-muted") { "#{@unsorted_count} #{'document'.pluralize(@unsorted_count)}" }
    end
  end

  def empty_state
    div(class: "rounded-lg border border-dashed border-line px-4 py-12 text-center") do
      p(class: "text-sm text-muted") { "No collections yet." }
      p(class: "mt-1 text-xs text-faint") { "Create one to start grouping documents, or upload a file to the archive." }
    end
  end

  def no_matches
    div(
      hidden: true,
      class: "col-span-full rounded-lg border border-dashed border-line px-4 py-8 text-center text-sm text-faint",
      data: { list_filter_target: "empty" }
    ) { "No collections match your filter." }
  end

  def updated(time)
    return "no activity yet" if time.nil?

    "updated #{time_ago_in_words(time)} ago"
  end

  def source_icon
    svg(width: "18", height: "18", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "1.6", aria_hidden: "true") do |s|
      s.path(d: "M3 8a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z")
    end
  end


  def search_icon
    svg(class: "text-faint", width: "18", height: "18", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", aria_hidden: "true") do |s|
      s.circle(cx: "11", cy: "11", r: "7")
      s.path(d: "m20 20-3.5-3.5")
    end
  end
end
