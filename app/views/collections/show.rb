# frozen_string_literal: true

# One collection: browse its documents, search within it (scope preset to this
# collection via ?c=<slug>), and manage manual memberships. The collection is
# never in the URL for a document — a doc lives in many collections — so context
# is carried in the breadcrumb, and /documents/:id stays canonical.
class Views::Collections::Show < Views::Base
  # Reuse the index's status-meter vocabulary so a collection reads the same
  # everywhere.
  METER = Views::Collections::Index::METER

  def initialize(collection:, document_rows:, status_counts:, source_fed:, candidates:, sources:, attachable_sources:)
    @collection = collection
    @document_rows = document_rows
    @status_counts = status_counts
    @source_fed = source_fed
    @candidates = candidates
    @sources = sources
    @attachable_sources = attachable_sources
  end

  def view_template
    breadcrumb(["Collections", collections_path], @collection.name)
    header_block
    search
    # Don't offer what will be refused: filing needs operator on this
    # collection, and a reader granted `user` has only search and chat here.
    if may_on?(@collection, :operator)
      sources_panel
      upload
      add_documents
    end
    documents_region
    delete_collection
  end

  private

  def page_title = @collection.name

  # What this collection draws on. It lives here rather than on the source
  # because feeding decides what this collection's readers see — that belongs
  # to whoever owns the collection, not to whoever owns the credentials.
  def sources_panel
    details(class: "mb-6 rounded-lg border border-line bg-ink/40", open: @sources.none?) do
      summary(class: "cursor-pointer list-none px-5 py-3.5 flex items-center justify-between gap-3") do
        span(class: "text-sm text-muted") { "Sources" }
        span(class: "font-mono tabular-nums text-xs text-faint") { fed_summary }
      end
      div(class: "border-t border-line/60 px-5 py-4") do
        @sources.any? ? fed_list : no_sources
        attach_form if @attachable_sources.any?
      end
    end
  end

  def fed_summary
    return "none" if @sources.none?

    "#{@sources.size} #{'source'.pluralize(@sources.size)}"
  end

  def fed_list
    ul(class: "mb-4 divide-y divide-line/60") do
      @sources.each do |source|
        li(class: "flex items-center justify-between gap-3 py-2.5") do
          span(class: "truncate text-sm text-fg") { source.name }
          detach_button(source)
        end
      end
    end
  end

  # No grant on the source needed: you may always stop drawing on something.
  def detach_button(source)
    form(
      action: collection_source_path(@collection, source),
      method: "post",
      class: "shrink-0",
      data: { turbo_confirm: "Stop “#{@collection.name}” drawing on #{source.name}? Documents it fed here are removed from this collection; nothing is deleted." }
    ) do
      input(type: "hidden", name: "_method", value: "delete")
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(type: "submit", class: "text-xs text-faint hover:text-red-300 transition-colors") { "Detach" }
    end
  end

  def no_sources
    p(class: "mb-4 text-xs text-faint") do
      "Nothing feeds this collection yet — its documents were all filed by hand."
    end
  end

  def attach_form
    form(action: collection_sources_path(@collection), method: "post", class: "flex flex-wrap items-end gap-3") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      div(class: "flex-1 basis-56 min-w-0") do
        label(class: "block mb-2 text-xs text-faint", for: "collection_source_id") { "Draw on another source" }
        select(id: "collection_source_id", name: "source_id", required: true, class: "w-full rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg outline-none focus:border-accent transition-colors") do
          option(value: "", disabled: true, selected: true) { "Choose a source…" }
          @attachable_sources.each { |source| option(value: source.id) { source.name } }
        end
      end
      button(
        type: "submit",
        class: "shrink-0 rounded border border-line px-3 py-2 text-sm text-muted hover:text-fg hover:border-line-2 transition-colors"
      ) { "Attach" }
    end
  end

  # Deliberately plain and at the bottom, not a red button next to the title.
  # The confirmation says what survives, because "delete collection" reads like
  # it might take the documents with it — it doesn't.
  def delete_collection
    return unless may_on?(@collection, :admin)

    div(class: "mt-10 border-t border-line/60 pt-5 flex items-center justify-between gap-4") do
      div do
        p(class: "text-sm text-muted") { "Delete this collection" }
        p(class: "mt-0.5 text-xs text-faint") do
          "Its documents stay in the archive. Any that are only in this collection become Unsorted."
        end
      end
      form(
        action: collection_path(@collection),
        method: "post",
        class: "shrink-0",
        data: { turbo_confirm: "Delete “#{@collection.name}”? Its documents stay in the archive, but this can't be undone." }
      ) do
        input(type: "hidden", name: "_method", value: "delete")
        input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
        button(
          type: "submit",
          class: "rounded border border-red-400/40 px-3 py-2 text-sm text-red-300 hover:bg-red-400/10 transition-colors"
        ) { "Delete" }
      end
    end
  end

  # Only for whoever administers this collection — an operator granted filing
  # rights here has no business handing out access.
  def people_link
    return unless may_on?(@collection, :admin)

    a(
      href: collection_people_path(@collection),
      class: "text-xs text-muted hover:text-fg transition-colors"
    ) { "People" }
  end

  def header_block
    header(class: "mb-7") do
      div(class: "mb-2 flex items-center justify-between gap-3") do
        h1(class: "text-2xl font-semibold tracking-tight") { @collection.name }
        div(class: "flex shrink-0 items-center gap-4") do
          source_marker if @source_fed
          people_link
        end
      end
      description
      # Swapped by the document list's poll, not its own — see #documents_region.
      div(id: "collection_meter") do
        meter
        p(class: "mt-3 text-sm text-muted") { count_summary }
      end
    end
  end

  # What this collection is for. It reads as prose to whoever opens the page and
  # goes to the chat model in `list_collections`, which is the harder audience:
  # a model choosing where to look has only this and the name to go on.
  def description
    p(class: "mb-3 text-sm leading-relaxed text-muted") { @collection.description } if @collection.description.present?
    description_editor if may_on?(@collection, :operator)
  end

  def description_editor
    details(class: "mb-4") do
      summary(class: "cursor-pointer list-none") { description_toggle }
      description_form
    end
  end

  # Dashed and quiet when there is no description — the app's vocabulary for
  # "not a real thing" (see docs/design.md) — and a plain secondary link once
  # there is one, because then the affordance is only a way back into an edit.
  def description_toggle
    return span(class: "text-xs text-faint hover:text-fg transition-colors") { "Edit description" } if @collection.description.present?

    span(class: "inline-flex items-center gap-2 rounded border border-dashed border-line px-3 py-2 text-xs text-muted hover:border-line-2 hover:text-fg transition-colors") do
      plain "Describe this collection"
      span(class: "text-faint") { "so agents know what it contains" }
    end
  end

  def description_form
    form(action: collection_path(@collection), method: "post", class: "mt-3 flex flex-col gap-2") do
      input(type: "hidden", name: "_method", value: "patch")
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      textarea(
        name: "collection[description]", rows: "3",
        placeholder: "What this collection is for, and what someone would come here to find.",
        class: "w-full resize-y rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg placeholder:text-faint outline-none focus:border-accent transition-colors"
      ) { @collection.description }
      button(type: "submit", class: "self-start rounded bg-accent px-3 py-1.5 text-sm font-medium text-void hover:bg-accent-dim transition-colors") { "Save" }
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
    span(class: "shrink-0 inline-flex items-center gap-1 text-xs text-faint", title: "Fed by a source") do
      span(class: "h-1.5 w-1.5 rounded-full bg-accent/70")
      plain "Source"
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
        form(action: documents_path, method: "post", enctype: "multipart/form-data") do
          input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
          input(type: "hidden", name: "collection_slug", value: @collection.slug)
          render Views::Documents::UploadFields.new
        end
      end
    end
  end

  # Add documents from the archive. A disclosure keeps the (potentially long)
  # picker out of the way until wanted; inside, a filter narrows the candidate
  # list and checkboxes add several at once — a live test of the picker paradigm
  # the scope picker will reuse.
  # Its own live region rather than a companion of the document list: it shows
  # documents that *aren't* in this collection, so it goes stale on its own
  # schedule — a collection whose own documents have all settled would otherwise
  # stop polling and leave a "Pending" here that never resolves.
  #
  # Being behind a disclosure is what makes that affordable. The poll skips a
  # region nobody can see, so a closed picker costs a timer tick and no request,
  # and opening it starts the refreshes within one interval.
  def add_documents
    details(class: "mb-6 rounded-lg border border-line bg-ink/40") do
      summary(class: "cursor-pointer list-none px-4 py-3 text-sm font-medium text-accent hover:text-accent-dim transition-colors") { "Add documents" }
      div(
        class: "border-t border-line p-4",
        id: "collection_candidates",
        data: progress_data(terminal: @candidates.all?(&:settled?))
      ) do
        @candidates.any? ? picker_form : no_candidates
      end
    end
  end

  def picker_form
    form(action: collection_documents_path(@collection), method: "post", data: { controller: "list-filter" }) do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
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

  # The page you land on after uploading into this collection, where the new file
  # sits pending while the pipeline works — and nothing broadcasts to a
  # collection, so this region polls itself fresh. The header's meter and counts
  # tally the same statuses, so they ride along on the same response instead of
  # drifting out of step with the badges below them. (The "Add documents" picker
  # watches a different set of documents and polls itself — see #add_documents.)
  def documents_region
    div(
      id: "collection_documents",
      data: progress_data(terminal: @document_rows.all? { |row| row.document.settled? }, also: ["collection_meter"])
    ) do
      @document_rows.any? ? document_list : empty_state
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
      div(class: "min-w-0 flex-1") do
        a(href: document_path(document), class: "block truncate text-sm font-medium text-fg hover:text-accent transition-colors") { document.title }
        provenance(document)
      end
      div(class: "flex shrink-0 items-center gap-3") do
        render Views::Documents::StatusBadge.new(status: document.status)
        # Only a manual membership is user-removable; a fed row is retracted at
        # the source, which the provenance line above names.
        remove_button(document) if row.origin == "manual" && may_on?(@collection, :operator)
        delete_button(document) if row.purgeable
      end
    end
  end

  def remove_button(document)
    form(action: collection_document_path(@collection, document), method: "post", class: "inline") do
      input(type: "hidden", name: "_method", value: "delete")
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(type: "submit", class: "text-xs text-faint hover:text-red-300 transition-colors") { "Remove" }
    end
  end

  # Remove's heavier neighbour, and a different act: out of the archive rather
  # than off this shelf. Outlined red rather than another quiet word, because
  # standing next to "Remove" the difference has to be visible before you read
  # the confirmation. Who gets it: CollectionsController#purgeable_document_ids.
  def delete_button(document)
    form(
      action: document_path(document),
      method: "post",
      class: "inline",
      data: { turbo_confirm: "Permanently delete “#{document.title}”? It leaves every collection and the archive — text, embeddings and file — and this can't be undone." }
    ) do
      input(type: "hidden", name: "_method", value: "delete")
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      button(
        type: "submit",
        class: "rounded border border-red-400/40 px-2 py-0.5 text-xs text-red-300 hover:bg-red-400/10 transition-colors"
      ) { "Delete" }
    end
  end

  # Which source produced this, and where it sits inside it. A blank path — a
  # manual upload, or anything at the top of its source — leaves the name alone.
  def provenance(document)
    text = [document.source.name, path_within_source(document)].compact.join(" · ")
    p(class: "mt-1 truncate text-xs text-faint", title: text) { text }
  end

  # Sources get named after whatever they point at, so the first segment is
  # usually the source name again — "Technology · Technology/Services". Drop
  # the echo. Nothing is left for a manual upload, or for anything sitting at
  # the top of its source.
  def path_within_source(document)
    segments = document.path.to_s.split("/")
    segments.shift if segments.first == document.source.name
    segments.join("/").presence
  end

  def empty_state
    div(class: "rounded-lg border border-dashed border-line px-4 py-12 text-center") do
      p(class: "text-sm text-muted") { "No documents in this collection yet." }
      # Don't tell a reader to upload something they have no way to upload.
      p(class: "mt-1 text-xs text-faint") do
        if may_on?(@collection, :operator)
          "Upload a file or add one from your archive."
        else
          "Whoever manages this collection hasn't added anything yet."
        end
      end
    end
  end

  def search_icon
    svg(class: "text-faint", width: "18", height: "18", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", aria_hidden: "true") do |s|
      s.circle(cx: "11", cy: "11", r: "7")
      s.path(d: "m20 20-3.5-3.5")
    end
  end
end
