# frozen_string_literal: true

# One instance-wide on/off, flipped in place on the settings index.
#
# A fragment rather than part of the page so Settings::PreferencesController can
# re-render just this row after a flip — same arrangement as
# Views::Sources::LastScan.
class Views::Settings::Toggle < Components::Base
  def self.dom_id(key) = "setting-#{key.tr('.', '-')}"

  def initialize(key:, on:)
    @key = key
    @on = on
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
    form(action: settings_preferences_path, method: "post", class: "shrink-0 pt-0.5") do
      input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
      input(type: "hidden", name: "_method", value: "patch")
      input(type: "hidden", name: "key", value: @key)
      # The value being moved to, so a double-click can't land somewhere
      # unintended and a stale page can't flip something it never showed.
      input(type: "hidden", name: "value", value: (!@on).to_s)
      render Views::Settings::Switch.new(on: @on, label: Setting.label(@key))
    end
  end
end
