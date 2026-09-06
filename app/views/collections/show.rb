# frozen_string_literal: true

# One collection: browse its documents, search within it (scope preset to this
# collection via ?c=<slug>), and manage manual memberships. The collection is
# never in the URL for a document — a doc lives in many collections — so context
# is carried in the breadcrumb, and /documents/:id stays canonical.
class Views::Collections::Show < Views::Base
  # Reuse the index's status-meter vocabulary so a collection reads the same
  # everywhere.
  METER = Views::Collections::Index::METER

  def initialize(collection:, document_rows:, status_counts:, connector_fed:, candidates:)
    @collection = collection
    @document_rows = document_rows
    @status_counts = status_counts
    @connector_fed = connector_fed
    @candidates = candidates
  end

  def view_template
    breadcrumb
    header_block
    search
    upload
    add_documents
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
          type: "text", name: "q", placeholder: "Search",
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

  # Upload a new file straight into this collection: it ingests through the
  # manual-upload pipeline and lands here as a manual membership. The hidden
  # collection_slug tells DocumentsController#create to file it and return here.
  def upload
    details(class: "mb-2 rounded-lg border border-line bg-ink/40") do
      summary(class: "cursor-pointer list-none px-4 py-3 text-sm font-medium text-accent hover:text-accent-dim transition-colors") { "Upload a file" }
      div(class: "border-t border-line p-4") do
        form(action: documents_path, method: "post", enctype: "multipart/form-data", class: "flex items-center gap-4") do
          input(type: "hidden", name: "authenticity_token", value: helpers.form_authenticity_token)
          input(type: "hidden", name: "collection_slug", value: @collection.slug)
          input(
            type: "file", name: "file", required: true,
            class: "block w-full text-sm text-muted file:mr-4 file:rounded file:border-0 " \
                   "file:bg-accent file:px-4 file:py-2 file:text-sm file:font-medium file:text-void " \
                   "hover:file:bg-accent-dim file:cursor-pointer"
          )
          button(type: "submit", class: "shrink-0 rounded bg-accent px-4 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors") { "Upload" }
        end
      end
    end
  end

  # Add documents from the archive. A disclosure keeps the (potentially long)
  # picker out of the way until wanted; inside, a filter narrows the candidate
  # list and checkboxes add several at once — a live test of the picker paradigm
  # the scope picker will reuse.
  def add_documents
    details(class: "mb-6 rounded-lg border border-line bg-ink/40") do
      summary(class: "cursor-pointer list-none px-4 py-3 text-sm font-medium text-accent hover:text-accent-dim transition-colors") { "Add documents" }
      div(class: "border-t border-line p-4") do
        @candidates.any? ? picker_form : no_candidates
      end
    end
  end

  def picker_form
    form(action: collection_documents_path(@collection), method: "post", data: { controller: "list-filter" }) do
      input(type: "hidden", name: "authenticity_token", value: helpers.form_authenticity_token)
      input(
        type: "text", placeholder: "Filter documents", autocomplete: "off",
        data: { list_filter_target: "query", action: "input->list-filter#filter" },
        class: "w-full rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg placeholder:text-faint outline-none focus:border-accent transition-colors"
      )
      div(class: "mt-3 max-h-64 overflow-y-auto rounded border border-line divide-y divide-line") do
        @candidates.each { |document| candidate_row(document) }
        no_candidate_matches
      end
      button(type: "submit", class: "mt-3 rounded bg-accent px-4 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors") { "Add selected" }
    end
  end

  def candidate_row(document)
    label(
      class: "flex items-center gap-3 px-3 py-2 hover:bg-ink/60 cursor-pointer",
      data: { list_filter_target: "item", name: document.title.to_s.downcase }
    ) do
      input(type: "checkbox", name: "document_ids[]", value: document.id, class: "size-4 shrink-0 accent-accent")
      span(class: "min-w-0 flex-1 truncate text-sm text-fg") { document.title }
      render Views::Documents::StatusBadge.new(status: document.status)
    end
  end

  def no_candidate_matches
    div(hidden: true, class: "px-3 py-6 text-center text-sm text-faint", data: { list_filter_target: "empty" }) { "No documents match your filter." }
  end

  def no_candidates
    p(class: "text-sm text-faint") { "Every document is already in this collection. Upload a new one to add more." }
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
