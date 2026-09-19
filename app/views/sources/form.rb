# frozen_string_literal: true

# The source form, shared by new and edit. A fragment, not a page — it
# inherits Components::Base so it renders bare inside whichever page wraps it.
#
# Holds what every source has; each type subclasses this for its own fields and
# names its subclass through `Source.form_component`.
class Views::Sources::Form < Components::Base
  def initialize(source:, collections:, endpoints: [], catalogue: nil)
    @source = source
    @collections = collections
    @endpoints = endpoints
    @catalogue = catalogue
  end

  # Shown above the form on the new and edit pages. Per type, because "changing
  # the folder re-scans from scratch" is advice only one type can act on.
  def self.new_heading = "Add a source"
  def self.new_blurb = ""
  def self.edit_blurb = ""

  def view_template
    form(action: action, method: "post", class: "flex flex-col gap-6") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "patch") if @source.persisted?
      input(type: "hidden", name: "type", value: @source.class.name)

      errors if @source.errors.any?

      field("Name", "A label for this source — how it appears throughout Archyve.") do
        text_input(:name, @source.name, placeholder: "Reference library", autofocus: true)
      end

      type_fields

      if @source.supports_sync?
        field("Scan every", "How often to look for changes. Documents whose contents haven't changed are never reprocessed.") do
          interval_input
        end
      end

      if @source.supports_ocr?
        field("Read text from images (OCR)", ocr_hint) do
          ocr_checkbox
        end
      end

      if @source.feeds_collections?
        field("Feeds collections", "Documents from this source automatically join these. Documents you filed by hand stay where you put them.") do
          collection_checkboxes
        end
      end

      actions
    end
  end

  private

  def type_fields
    raise Source::MissingImplementationError, "#{self.class.name} must implement #type_fields"
  end

  def action
    @source.persisted? ? source_path(@source) : sources_path
  end

  def errors
    div(class: "rounded border border-red-400/40 bg-red-400/5 px-4 py-3") do
      p(class: "text-sm font-medium text-red-300") { "This source couldn't be saved." }
      ul(class: "mt-1.5 list-disc pl-4 text-sm text-red-300/80") do
        @source.errors.full_messages.each { |message| li { message } }
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
      name: "source[#{name}]",
      value: value,
      placeholder: placeholder,
      autofocus: autofocus,
      autocomplete: "off",
      class: "#{input_classes} #{'font-mono' if mono}"
    )
  end

  def input_classes
    "w-full rounded border border-line bg-void/60 px-3 py-2 text-sm text-fg placeholder:text-faint " \
      "outline-none focus:border-accent transition-colors"
  end

  # A quiet box for things the form is telling you rather than asking you.
  def note(&)
    div(class: "rounded border border-line bg-void/40 px-3 py-2.5", &)
  end

  def interval_input
    div(class: "flex items-center gap-2") do
      input(
        type: "number",
        name: "source[sync_interval_minutes]",
        value: @source.sync_interval_minutes || Source::DEFAULT_SYNC_INTERVAL_MINUTES,
        min: "1",
        class: "w-28 rounded border border-line bg-void/60 px-3 py-2 font-mono text-sm text-fg outline-none focus:border-accent transition-colors"
      )
      span(class: "text-sm text-muted") { "minutes" }
    end
  end

  # Per source rather than per install: a folder of scanned receipts and a
  # folder of exported Markdown want opposite answers, and they can sit side by
  # side in one archive.
  def ocr_hint
    "Runs every page through text recognition. Needed for scans; on documents that already have " \
      "selectable text it only makes conversion slower and far more memory-hungry."
  end

  # Same hidden-then-checkbox pair as the collection feeds below, and for the
  # same reason: an unchecked box submits nothing, which would read as "leave
  # it as it was" rather than "turn it off".
  def ocr_checkbox
    input(type: "hidden", name: "source[ocr]", value: "0")

    label(class: "flex cursor-pointer items-center gap-2.5 text-sm text-muted hover:text-fg transition-colors") do
      input(
        type: "checkbox",
        name: "source[ocr]",
        value: "1",
        checked: @source.ocr?,
        class: "h-3.5 w-3.5 accent-accent"
      )
      plain "Use OCR on documents from this source"
    end
  end

  def collection_checkboxes
    return no_collections if @collections.empty?

    # An empty hidden value so clearing every box submits an empty list rather
    # than omitting the key, which would read as "leave them as they were".
    input(type: "hidden", name: "source[collection_ids][]", value: "")

    div(class: "flex flex-col gap-1.5 rounded border border-line bg-void/40 p-3") do
      @collections.each { |collection| collection_checkbox(collection) }
    end
  end

  def collection_checkbox(collection)
    label(class: "flex cursor-pointer items-center gap-2.5 text-sm text-muted hover:text-fg transition-colors") do
      input(
        type: "checkbox",
        name: "source[collection_ids][]",
        value: collection.id,
        checked: @source.collection_ids.include?(collection.id),
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
      ) { @source.persisted? ? "Save" : "Create source" }
      a(href: cancel_path, class: "text-sm text-muted hover:text-fg transition-colors") { "Cancel" }
    end
  end

  def cancel_path
    @source.persisted? ? source_path(@source) : sources_path
  end
end
