# frozen_string_literal: true

# One instance-wide number, edited in place on the settings index — the same row
# shape as Views::Settings::Toggle, but with a Save step, since a half-typed
# number must not be written.
class Views::Settings::Number < Components::Base
  # In the order a turn spends them, not the order they were added.
  KEYS = %w[chat.max_search_rounds chat.max_read_rounds chat.max_listing_rounds].freeze

  def self.dom_id(key) = "setting-#{key.tr('.', '-')}"

  def initialize(key:, value:)
    @key = key
    @value = value
  end

  def view_template
    div(id: self.class.dom_id(@key), class: "flex items-start justify-between gap-4 py-4") do
      div(class: "min-w-0") do
        p(class: "text-sm font-medium text-fg") { Setting.label(@key) }
        p(class: "mt-0.5 text-xs text-faint") { Setting.description(@key) }
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
      aria_label: Setting.label(@key), inputmode: "numeric",
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
