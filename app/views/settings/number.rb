# frozen_string_literal: true

# One instance-wide number, edited in place on the settings index — the same row
# shape as Views::Settings::Toggle, but with a Save step, since a half-typed
# number must not be written.
class Views::Settings::Number < Components::Base
  # The words belong to the UI, not to Setting: DEFINITIONS descriptions are
  # notes for whoever reads that file, and are written as such.
  COPY = {
    "chat.max_search_rounds" => {
      label: "Searches per turn",
      description: "How many times the chat model may search the archive while answering one " \
        "question. Two lets it search, read what came back, and search again with better words."
    },
    "chat.max_read_rounds" => {
      label: "Documents read per turn",
      description: "How many documents the chat model may open while answering one question. " \
        "Reading is how it checks what a search turned up; a model that runs out part way " \
        "through reports the documents it couldn't open rather than reading them."
    },
    "chat.max_listing_rounds" => {
      label: "Listings per turn",
      description: "How many times the chat model may list what a collection holds, rather than " \
        "search inside it. Listing costs no search of its own, and finding a way around the " \
        "archive takes more steps than answering from it."
    }
  }.freeze

  def self.dom_id(key) = "setting-#{key.tr('.', '-')}"

  def initialize(key:, value:)
    @key = key
    @value = value
    @copy = COPY.fetch(key)
  end

  def view_template
    div(id: self.class.dom_id(@key), class: "flex items-start justify-between gap-4 py-4") do
      div(class: "min-w-0") do
        p(class: "text-sm font-medium text-fg") { @copy[:label] }
        p(class: "mt-0.5 text-xs text-faint") { @copy[:description] }
      end
      control
    end
  end

  private

  def control
    form(action: settings_preferences_path, method: "post", class: "flex shrink-0 items-center gap-2 pt-0.5") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "patch")
      input(type: "hidden", name: "key", value: @key)
      field
      save
    end
  end

  # The browser's own increment arrows are drawn in its colours, not ours, and
  # a brass-on-void row can't absorb them — so the field keeps the number
  # semantics and loses the spinner.
  NO_SPINNER = "[appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none " \
               "[&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:m-0"

  def field
    input(
      type: "number", name: "value", value: @value.to_s, min: "1", step: "1",
      aria_label: @copy[:label], inputmode: "numeric",
      class: "w-14 rounded border border-line bg-void/60 px-2 py-1 text-center font-mono tabular-nums " \
        "text-sm text-fg outline-none focus:border-accent transition-colors #{NO_SPINNER}"
    )
  end

  def save
    button(
      type: "submit",
      class: "rounded bg-accent px-3 py-1 text-sm font-medium text-void hover:bg-accent-dim transition-colors"
    ) { "Save" }
  end
end
