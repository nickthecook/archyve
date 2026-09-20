# frozen_string_literal: true

# "Unsorted": live documents that aren't in any collection. A derived view, not a
# real collection — so it lives off the Collections index (breadcrumb back) and
# reads quietly. Two things to do with a selection: sort it into a collection, or
# delete it from the archive. Either way it leaves this list.
class Views::Unsorted::Index < Views::Base
  def initialize(documents:, collections:)
    @documents = documents
    @collections = collections
  end

  def view_template
    breadcrumb
    header_block
    @documents.any? ? sorter : empty_state
  end

  private

  def page_title = "Unsorted"

  def breadcrumb
    nav(class: "mb-5 flex items-center gap-2 text-xs text-faint") do
      a(href: collections_path, class: "hover:text-muted transition-colors") { "Collections" }
      span { "›" }
      span(class: "text-muted") { "Unsorted" }
    end
  end

  def header_block
    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Unsorted" }
      p(class: "mt-1 text-sm text-muted") do
        count = @documents.size
        "#{count} #{'document'.pluralize(count)} not in any collection."
      end
    end
  end

  # Pick documents (checkboxes, narrowed by the filter), then either assign them
  # to the chosen collection or delete them. One form, two submit buttons — see
  # #purge_button.
  #
  # The form is also the polled region, rather than just the list inside it: the
  # filter narrows by hiding rows, so swapping the rows without the query box
  # would leave a filter that claims to be applied and isn't. The controller
  # holds off entirely while there's a selection or a query to lose.
  def sorter
    form(
      action: assign_unsorted_path,
      method: "post",
      id: "unsorted",
      data: progress_data(terminal: @documents.all?(&:settled?), controller: "list-filter progress")
    ) do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      toolbar
      document_list
    end
  end

  def toolbar
    div(class: "mb-4 flex flex-wrap items-center gap-3") do
      input(
        type: "text", placeholder: "Filter documents", autocomplete: "off",
        data: { list_filter_target: "query", action: "input->list-filter#filter" },
        class: "flex-1 rounded border border-line bg-ink/40 px-3 py-2 text-sm text-fg placeholder:text-faint outline-none focus:border-line-2 transition-colors"
      )
      @collections.any? ? assign_controls : create_hint
      purge_button
    end
  end

  # The second thing to do with the selection, on the same form: `formaction`
  # sends it elsewhere, so the rows need no nested form of their own. Offered
  # with or without a collection to file into — a queue with nowhere to sort
  # things into is exactly when clearing it out is the only move left.
  def purge_button
    button(
      type: "submit",
      formaction: purge_unsorted_path,
      data: { turbo_confirm: "Permanently delete the selected documents? They leave the archive — text, embeddings and file — and this can't be undone." },
      class: "shrink-0 rounded border border-red-400/40 px-3 py-2 text-sm text-red-300 hover:bg-red-400/10 transition-colors"
    ) { "Delete" }
  end

  def assign_controls
    select(
      name: "collection_slug",
      class: "shrink-0 rounded border border-line bg-ink/60 px-3 py-2 text-sm text-fg outline-none focus:border-accent transition-colors"
    ) do
      @collections.each { |collection| option(value: collection.slug) { collection.name } }
    end
    button(
      type: "submit",
      class: "shrink-0 rounded bg-accent px-4 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
    ) { "Add to collection" }
  end

  def create_hint
    span(class: "shrink-0 text-xs text-faint") { "Create a collection to sort these into." }
  end

  def document_list
    ul(class: "divide-y divide-line rounded-lg border border-line bg-ink/40") do
      @documents.each { |document| document_row(document) }
      no_matches
    end
  end

  def document_row(document)
    li(
      class: "flex items-center gap-3 px-5 py-4",
      data: { list_filter_target: "item", name: document.title.to_s.downcase }
    ) do
      input(type: "checkbox", name: "document_ids[]", value: document.id, class: "size-4 shrink-0 accent-accent")
      a(href: document_path(document), class: "min-w-0 flex-1 truncate text-sm font-medium text-fg hover:text-accent transition-colors") { document.title }
      render Views::Documents::StatusBadge.new(status: document.status)
      fed_marker(document) unless document.purgeable?
    end
  end

  # Selectable like any other row — it can still be filed — but say up front
  # that deleting it won't take, rather than let the notice explain afterwards.
  def fed_marker(document)
    span(
      class: "shrink-0 text-xs text-faint",
      title: "Fed by #{document.source.name} — a sync would put it back. Remove it there instead."
    ) { "Source" }
  end

  def no_matches
    li(hidden: true, class: "px-5 py-8 text-center text-sm text-faint", data: { list_filter_target: "empty" }) { "No documents match your filter." }
  end

  def empty_state
    div(class: "rounded-lg border border-dashed border-line px-4 py-12 text-center") do
      p(class: "text-sm text-muted") { "Nothing unsorted." }
      p(class: "mt-1 text-xs text-faint") { "Every document is in a collection." }
    end
  end
end
