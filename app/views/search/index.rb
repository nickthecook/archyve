# frozen_string_literal: true

class Views::Search::Index < Views::Base
  def initialize(query:, results:, error: nil, scope: nil)
    @query = query
    @results = results
    @error = error
    @scope = scope
  end

  def view_template
    search_box
    error_panel if @error
    @query.blank? ? prompt : results
  end

  private

  def page_title = @query.present? ? "Search · #{@query}" : "Search"

  def search_box
    form(action: search_path, method: "get", class: "mb-8") do
      scope_fields
      div(class: "flex items-center gap-3 rounded border border-line-2 bg-ink/60 px-4 py-3 focus-within:border-accent transition-colors") do
        svg(class: "text-faint", width: "18", height: "18", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", aria_hidden: "true") do |s|
          s.circle(cx: "11", cy: "11", r: "7")
          s.path(d: "m20 20-3.5-3.5")
        end
        input(
          type: "text", name: "q", value: @query, placeholder: "Search your archive",
          autofocus: true, autocomplete: "off",
          class: "flex-1 bg-transparent text-fg placeholder:text-faint outline-none text-[0.95rem]"
        )
        scope_chip
      end
    end
  end

  # Re-emit the active scope so a follow-up query stays scoped. Array values
  # (c) become repeated name="c[]" fields.
  def scope_fields
    return unless @scope

    @scope.hidden_params.each do |name, value|
      Array(value).each { |v| input(type: "hidden", name: "#{name}#{'[]' if value.is_a?(Array)}", value: v) }
    end
  end

  def scope_chip
    label = @scope ? "In #{@scope.label}" : "All collections"
    span(class: "shrink-0 inline-flex items-center gap-1.5 rounded-full border border-line px-2.5 py-1 text-xs text-muted") do
      span(class: "h-1.5 w-1.5 rounded-full bg-accent")
      plain label
    end
  end

  def prompt
    div(class: "text-center py-16") do
      p(class: "text-sm text-muted") { @scope ? "Search within #{@scope.label}." : "Search across every collection." }
    end
  end

  def error_panel
    div(class: "mb-6 rounded border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-300") { @error }
  end

  def results
    if @results.empty?
      div(class: "text-center py-16") { p(class: "text-sm text-muted") { "No matches for “#{@query}”." } }
      return
    end

    p(class: "mb-4 text-xs font-mono text-faint") { "#{@results.size} #{'result'.pluralize(@results.size)}" }
    div(class: "space-y-3") { @results.each { |embedding| result_card(embedding) } }
  end

  def result_card(embedding)
    chunk = embedding.chunk
    document = chunk.document
    breadcrumb = Array(chunk.structure["heading_path"]).join(" › ")

    # A div, not a link: the card carries its own actions, and an anchor can't
    # contain anchors.
    div(class: "rounded-lg border border-line bg-ink/40 p-4") do
      div(class: "mb-1.5 flex items-center justify-between gap-3") do
        span(class: "truncate text-sm font-medium text-fg") { document.title }
        span(class: "shrink-0 font-mono text-xs text-accent tabular-nums") { "#{similarity(embedding)}%" }
      end
      span(class: "block text-xs text-faint truncate mb-2") { breadcrumb } if breadcrumb.present?
      p(class: "text-sm leading-relaxed text-muted") { chunk.content.truncate(260) }
      actions(document, chunk)
    end
  end

  # Getting the document is the same for everyone — download it, or follow it to
  # its source. Inspecting how retrieval chunked it is an operator's tool, so it
  # sits behind the role rather than being the card's primary action.
  def actions(document, chunk)
    div(class: "mt-3 flex items-center gap-4 border-t border-line/60 pt-3") do
      render Views::Documents::Access.new(document:)
      if may?(:operator)
        a(
          href: document_path(document, anchor: ActionView::RecordIdentifier.dom_id(chunk)),
          class: "text-xs text-faint hover:text-fg transition-colors"
        ) { "Inspect chunks" }
      end
    end
  end

  # cosine distance (0 identical … 2 opposite) → a friendly similarity percentage
  def similarity(embedding)
    ((1 - embedding.neighbor_distance) * 100).round.clamp(0, 100)
  end
end
