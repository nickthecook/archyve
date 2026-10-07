# frozen_string_literal: true

# The on/off control itself, split from the row around it so the style guide can
# show both states side by side without a live form behind them.
class Views::Settings::Switch < Components::Base
  def initialize(on:, label:, type: "submit")
    @on = on
    @label = label
    @type = type
  end

  def view_template
    button(
      type: @type,
      role: "switch",
      aria_checked: @on.to_s,
      aria_label: @label,
      class: "relative inline-flex h-5 w-9 items-center rounded-full border transition-colors #{track}"
    ) do
      span(class: "block h-3.5 w-3.5 rounded-full transition-transform #{knob}")
    end
  end

  private

  # Brass only while on — it is reporting a state that costs something, which is
  # what the accent is for.
  def track
    @on ? "border-accent bg-accent" : "border-line bg-void hover:border-line-2"
  end

  def knob
    @on ? "translate-x-[18px] bg-void" : "translate-x-[3px] bg-muted"
  end
end
