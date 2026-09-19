# frozen_string_literal: true

class Views::Sources::Forms::Bookstack < Views::Sources::Form
  KINDS = [
    ["shelf", "Shelves", "Everything on the shelf, including books added to it later."],
    ["book", "Books", "Every page in the book, chaptered or not."],
    ["chapter", "Chapters", "Only that chapter's pages."]
  ].freeze

  def self.new_heading = "Add a BookStack wiki"

  def self.new_blurb
    "Archyve reads the pages you pick and keeps the archive matching them. Pages only — shelves, books and chapters give a page its path, never a document of their own."
  end

  def self.edit_blurb
    "Unticking a container doesn't delete anything you filed by hand: its pages stop being fed, and the ones only this source put in a collection are retired."
  end

  private

  def type_fields
    field("Server", server_hint) { server_picker }
    field("What to sync", "Pick as many as you like. Everything inside is taken, and stays in step as pages are added and removed.") { selector_picker }
  end

  def server_hint
    return "Fixed once the source exists — a source's documents are identified within the server that produced them." if @source.persisted?

    "The wiki, and the API token Archyve reads it with. Archyve sees exactly what that token's BookStack user sees."
  end

  # Fixed after creation: repointing a source at a different wiki would leave
  # every document keyed by a page id that means something else there.
  def server_picker
    return note { p(class: "text-sm text-fg") { @source.endpoint&.name || "none" } } if @source.persisted?
    return no_endpoints if @endpoints.empty?

    div(class: "flex items-center gap-2") do
      select(name: "source[endpoint_id]", class: input_classes) do
        @endpoints.each do |endpoint|
          option(value: endpoint.id, selected: endpoint.id == @source.endpoint_id) { endpoint.name }
        end
      end
      browse_button
    end
  end

  # A GET back to this same page, so switching server re-lists what's on it.
  # The form's own fields ride along in the query string, so nothing typed so
  # far is lost. `formmethod` rather than JavaScript: the list comes from the
  # wiki, so it was always going to be a round trip.
  def browse_button
    button(
      type: "submit",
      formmethod: "get",
      formaction: new_source_path(type: @source.class.name),
      class: "shrink-0 rounded border border-line px-3 py-2 text-sm text-muted hover:text-fg hover:border-line-2 transition-colors"
    ) { "Browse" }
  end

  def no_endpoints
    note do
      p(class: "text-sm text-fg") { "No BookStack servers yet." }
      p(class: "mt-1 text-xs text-faint") do
        plain "Add one under "
        a(href: new_settings_endpoint_path, class: "text-accent hover:underline") { "Settings → Endpoints" }
        plain ", then come back — the token is typed once per wiki, however many sources read it."
      end
    end
  end

  def selector_picker
    return catalogue_error if @catalogue&.error
    return nothing_to_pick if containers.empty?

    # Unticking everything has to submit an empty list rather than omitting the
    # key, or "sync nothing" would read as "leave it as it was".
    input(type: "hidden", name: "source[selectors][]", value: "")

    div(class: "flex flex-col gap-3", data: { controller: "list-filter" }) do
      filter_input if containers.size > 12
      div(class: "max-h-[28rem] overflow-y-auto rounded border border-line bg-void/40 divide-y divide-line") do
        KINDS.each { |kind, label_text, hint| group(kind, label_text, hint) }
      end
      p(class: "text-xs text-faint", data: { list_filter_target: "empty" }, hidden: true) { "Nothing matches." }
    end
  end

  def filter_input
    input(
      type: "search",
      placeholder: "Filter…",
      autocomplete: "off",
      data: { list_filter_target: "query", action: "input->list-filter#filter" },
      class: input_classes
    )
  end

  def group(kind, label_text, hint)
    of_kind = containers.select { |container| container.kind == kind }
    return if of_kind.empty?

    div do
      div(class: "sticky top-0 bg-ink px-4 py-2") do
        p(class: "text-xs font-medium text-muted") { label_text }
        p(class: "text-[0.7rem] text-faint") { hint }
      end
      div(class: "divide-y divide-line") { of_kind.each { |container| row(container) } }
    end
  end

  def row(container)
    label(
      class: "flex cursor-pointer items-center gap-3 px-4 py-2.5 hover:bg-ink/60 transition-colors",
      data: { list_filter_target: "item", name: filter_name(container) }
    ) do
      input(
        type: "checkbox",
        name: "source[selectors][]",
        value: container.token,
        checked: picked.include?([container.kind, container.id]),
        class: "h-3.5 w-3.5 shrink-0 accent-accent"
      )
      span(class: "min-w-0 truncate text-sm text-fg") { container.name }
      span(class: "shrink-0 text-xs text-faint") { container.context } if container.context
    end
  end

  def filter_name(container) = [container.name, container.context].compact.join(" ").downcase

  def catalogue_error
    div(class: "rounded border border-red-400/40 bg-red-400/5 px-3 py-2.5") do
      p(class: "text-sm text-red-300") { "Couldn't read #{@source.endpoint&.name}." }
      p(class: "mt-1 font-mono text-xs text-red-300/70") { @catalogue.error }
      p(class: "mt-1.5 text-xs text-faint") { "Check the endpoint's address and token, then Browse again." }
    end
  end

  def nothing_to_pick
    note do
      p(class: "text-sm text-fg") { "Nothing to sync on this server." }
      p(class: "mt-1 text-xs text-faint") do
        "The token's BookStack user can't see any shelves, books or chapters. That is a permissions question on the wiki."
      end
    end
  end

  def containers = @catalogue&.containers || []
  def picked = @picked ||= @source.selections
end
