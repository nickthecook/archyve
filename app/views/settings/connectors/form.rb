# frozen_string_literal: true

# The connector form, shared by new and edit. A fragment, not a page — it
# inherits Components::Base so it renders bare inside whichever page wraps it.
class Views::Settings::Connectors::Form < Components::Base
  def initialize(connector:, collections:)
    @connector = connector
    @collections = collections
  end

  def view_template
    form(action: action, method: "post", class: "flex flex-col gap-6") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "patch") if @connector.persisted?
      input(type: "hidden", name: "type", value: @connector.class.name)

      errors if @connector.errors.any?

      field("Name", "A label for this source — how it appears throughout Archyve.") do
        text_input(:name, @connector.name, placeholder: "Reference library", autofocus: true)
      end

      field("Folder", "An absolute path on the machine running Archyve. Read, never written.") do
        text_input(:path, @connector.path, placeholder: "/srv/documents", mono: true)
        what_gets_scanned
      end

      field("Scan every", "How often to look for changes. Files whose contents haven't changed are never reprocessed.") do
        interval_input
      end

      field("Feeds collections", "Documents from this source automatically join these. Documents you filed by hand stay where you put them.") do
        collection_checkboxes
      end

      actions
    end
  end

  private

  def action
    @connector.persisted? ? settings_connector_path(@connector) : settings_connectors_path
  end

  def errors
    div(class: "rounded border border-red-400/40 bg-red-400/5 px-4 py-3") do
      p(class: "text-sm font-medium text-red-300") { "This connector couldn't be saved." }
      ul(class: "mt-1.5 list-disc pl-4 text-sm text-red-300/80") do
        @connector.errors.full_messages.each { |message| li { message } }
      end
    end
  end

  def field(label_text, hint)
    div do
      label(class: "block text-sm font-medium text-fg") { label_text }
      p(class: "mt-0.5 mb-2 text-xs text-faint") { hint }
      yield
    end
  end

  def text_input(name, value, placeholder:, mono: false, autofocus: false)
    input(
      type: "text",
      name: "connector[#{name}]",
      value: value,
      placeholder: placeholder,
      autofocus: autofocus,
      autocomplete: "off",
      class: "w-full rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg placeholder:text-faint outline-none focus:border-accent transition-colors #{'font-mono' if mono}"
    )
  end

  # Which files the scan will actually pick up. Stated up front rather than left
  # to be discovered by a file not showing up. Not editable yet — when it is,
  # this becomes the input rather than the description of a constant.
  def what_gets_scanned
    div(class: "mt-2 rounded border border-line bg-void/40 px-3 py-2.5") do
      p(class: "text-xs text-muted") { "Scanned, recursively:" }
      div(class: "mt-1.5 flex flex-wrap gap-1") do
        Connectors::Folder::EXTENSIONS.each do |extension|
          span(class: "rounded border border-line px-1.5 py-0.5 font-mono text-[0.7rem] text-faint") { extension }
        end
      end
      p(class: "mt-2 text-xs text-faint") { skipped_summary }
    end
  end

  def skipped_summary
    limit = ActiveSupport::NumberHelper.number_to_human_size(Connectors::Folder.max_file_size)
    "Other extensions are ignored. Hidden files, symlinks, empty files, and files over #{limit} are skipped."
  end

  def interval_input
    div(class: "flex items-center gap-2") do
      input(
        type: "number",
        name: "connector[sync_interval_minutes]",
        value: @connector.sync_interval_minutes || Connectors::Folder::DEFAULT_SYNC_INTERVAL_MINUTES,
        min: "1",
        class: "w-28 rounded border border-line bg-void/60 px-3 py-2 font-mono text-sm text-fg outline-none focus:border-accent transition-colors"
      )
      span(class: "text-sm text-muted") { "minutes" }
    end
  end

  def collection_checkboxes
    return no_collections if @collections.empty?

    # An empty hidden value so clearing every box submits an empty list rather
    # than omitting the key, which would read as "leave them as they were".
    input(type: "hidden", name: "connector[collection_ids][]", value: "")

    div(class: "flex flex-col gap-1.5 rounded border border-line bg-void/40 p-3") do
      @collections.each { |collection| collection_checkbox(collection) }
    end
  end

  def collection_checkbox(collection)
    label(class: "flex cursor-pointer items-center gap-2.5 text-sm text-muted hover:text-fg transition-colors") do
      input(
        type: "checkbox",
        name: "connector[collection_ids][]",
        value: collection.id,
        checked: @connector.collection_ids.include?(collection.id),
        class: "h-3.5 w-3.5 accent-accent"
      )
      plain collection.name
    end
  end

  def no_collections
    p(class: "rounded border border-dashed border-line px-3 py-4 text-center text-xs text-faint") do
      plain "No collections yet — documents from this source will land in Unsorted."
    end
  end

  def actions
    div(class: "flex items-center gap-3") do
      button(
        type: "submit",
        class: "rounded bg-accent px-4 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
      ) { @connector.persisted? ? "Save" : "Create connector" }
      a(href: cancel_path, class: "text-sm text-muted hover:text-fg transition-colors") { "Cancel" }
    end
  end

  def cancel_path
    @connector.persisted? ? settings_connector_path(@connector) : settings_connectors_path
  end
end
