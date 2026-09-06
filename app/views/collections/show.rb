# frozen_string_literal: true

# One collection: browse its documents, search within it (scope preset to this
# collection via ?c=<slug>), and manage manual memberships. The collection is
# never in the URL for a document — a doc lives in many collections — so context
# is carried in the breadcrumb, and /documents/:id stays canonical.
class Views::Collections::Show < Views::Base
  # Reuse the index's status-meter vocabulary so a collection reads the same
  # everywhere.
  METER = Views::Collections::Index::METER

  def initialize(collection:, document_rows:, status_counts:, connector_fed:)
    @collection = collection
    @document_rows = document_rows
    @status_counts = status_counts
    @connector_fed = connector_fed
  end

  def view_template
    breadcrumb
    header_block
    search
    @document_rows.any? ? document_list : empty_state
  end

  private

  def page_title = @collection.name

  def breadcrumb
    nav(class: "mb-5 flex items-center gap-2 text-xs text-faint") do
      a(href: collections_path, class: "hover:text-muted transition-colors") { "Collections" }
      span { "›" }
      span(class: "text-muted") { @collection.name }
    end
  end

  def header_block
    header(class: "mb-7") do
      div(class: "mb-2 flex items-center justify-between gap-3") do
        h1(class: "text-2xl font-semibold tracking-tight") { @collection.name }
        source_marker if @connector_fed
      end
      meter
      p(class: "mt-3 text-sm text-muted") { count_summary }
    end
  end

  # Segmented health bar for this collection's active documents (see the index).
  def meter
    total = @document_rows.size
    div(class: "flex h-1.5 w-full overflow-hidden rounded-full bg-line/50") do
      next if total.zero?

      METER.each_key do |status|
        count = @status_counts[status].to_i
        next if count.zero?

        div(class: "h-full #{METER[status]}", style: "width: #{(count.to_f / total * 100).round(2)}%", title: "#{count} #{status}")
      end
    end
  end

  def count_summary
    total = @document_rows.size
    return "No documents yet." if total.zero?

    processed = @status_counts["processed"].to_i
    "#{total} #{'document'.pluralize(total)} · #{processed} processed"
  end

  def source_marker
    span(class: "shrink-0 inline-flex items-center gap-1 text-xs text-faint", title: "Fed by a connector") do
      span(class: "h-1.5 w-1.5 rounded-full bg-accent/70")
      plain "Connector"
    end
  end

  # Search preset to this collection: ?c=<slug>. The chip names the active scope.
  def search
    form(action: search_path, method: "get", class: "mb-8") do
      input(type: "hidden", name: "c", value: @collection.slug)
      div(class: "flex items-center gap-3 rounded border border-line-2 bg-ink/60 px-4 py-3 focus-within:border-accent transition-colors") do
        search_icon
        input(
          type: "text", name: "q", placeholder: "Search within #{@collection.name}",
          autocomplete: "off",
          class: "flex-1 bg-transparent text-fg placeholder:text-faint outline-none text-[0.95rem]"
        )
        span(class: "shrink-0 inline-flex items-center gap-1.5 rounded-full border border-line px-2.5 py-1 text-xs text-muted", title: "Search targets this collection") do
          span(class: "h-1.5 w-1.5 rounded-full bg-accent")
          plain "In #{@collection.name}"
        end
      end
    end
  end

  def document_list
    ul(class: "divide-y divide-line rounded-lg border border-line bg-ink/40") do
      @document_rows.each { |row| document_row(row) }
    end
  end

  def document_row(row)
    document = row.document
    li(class: "flex items-center justify-between gap-3 px-5 py-4") do
      a(href: document_path(document), class: "min-w-0 flex-1 truncate text-sm font-medium text-fg hover:text-accent transition-colors") { document.title }
      div(class: "flex shrink-0 items-center gap-3") do
        render Views::Documents::StatusBadge.new(status: document.status)
        row.source == "manual" ? remove_button(document) : connector_tag
      end
    end
  end

  def remove_button(document)
    form(action: collection_document_path(@collection, document), method: "post", class: "inline") do
      input(type: "hidden", name: "_method", value: "delete")
      input(type: "hidden", name: "authenticity_token", value: helpers.form_authenticity_token)
      button(type: "submit", class: "text-xs text-faint hover:text-red-300 transition-colors") { "Remove" }
    end
  end

  # A connector-fed row isn't user-removable — it's retracted at the connector.
  def connector_tag
    span(class: "text-xs text-faint", title: "Fed by a connector — remove it at the source") { "Connector" }
  end

  def empty_state
    div(class: "rounded-lg border border-dashed border-line px-4 py-12 text-center") do
      p(class: "text-sm text-muted") { "No documents in this collection yet." }
      p(class: "mt-1 text-xs text-faint") { "Upload a file or add one from your archive." }
    end
  end

  def search_icon
    svg(class: "text-faint", width: "18", height: "18", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", aria_hidden: "true") do |s|
      s.circle(cx: "11", cy: "11", r: "7")
      s.path(d: "m20 20-3.5-3.5")
    end
  end
end
