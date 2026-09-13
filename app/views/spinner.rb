# frozen_string_literal: true

# The brand triangle, spinning: Archyve's "working on it" indicator.
#
# The motion is a beat rather than a continuous spin — the mark travels, stops,
# travels again. An equilateral triangle repeats every 120°, so a 300° beat is
# five-sixths of a turn of visible movement for a 60° change, and each stop
# lands the mark flipped: point-up, point-down, point-up.
#
# ## Tuning
#
# DEGREES and BEAT_MS are the dials, and the whole cycle is two beats. Keep
# `DEGREES * 2` a multiple of 120 or the loop snaps when it restarts — the
# animation ends at twice the angle and jumps back to zero, which is only
# invisible when those two are the same picture. 180 and 300 both work; 200
# does not.
#
# The travel-to-hold split within a beat is not here: keyframe stops can't be
# custom properties, so it lives in the `brand-spin` keyframes in
# app/assets/tailwind/application.css. Beyond about a 300ms hold the mark stops
# reading as working and starts reading as stalled.
class Views::Spinner < Components::Base
  DEGREES = 300
  BEAT_MS = 1700
  EASE = "cubic-bezier(0.65, 0, 0.35, 1)"

  # Equilateral, unlike the header mark in Views::Chrome — that one is 22 wide
  # by 18 tall, so its corners sit at 118.6°/122.8°/118.6° and a 60° turn lands
  # visibly off-axis. Here the centroid is the box centre too, so the mark spins
  # in place instead of precessing around it.
  POINTS = "12,1 21.53,17.5 2.47,17.5"
  STROKE = 1.6

  # Inherits its colour, so callers place it with text-accent (or text-faint for
  # a background task) rather than the component deciding.
  def initialize(size: 15, label: nil)
    @size = size
    @label = label
  end

  def view_template
    svg(**attributes) do |s|
      s.polygon(points: POINTS, fill: "none", stroke: "currentColor", stroke_width: STROKE)
    end
  end

  private

  # Unlabelled by default: the spinner almost always sits beside text that
  # already says what is happening, and announcing it twice is worse than not
  # at all.
  def attributes
    base = {
      class: "brand-spin overflow-visible",
      width: @size, height: @size, viewbox: "0 0 24 24", fill: "none", style: custom_properties
    }
    @label ? base.merge(role: "img", aria_label: @label) : base.merge(aria_hidden: "true")
  end

  def custom_properties
    "--spin-to:#{DEGREES}deg;--spin-around:#{DEGREES * 2}deg;" \
      "--spin-cycle:#{BEAT_MS * 2}ms;--spin-ease:#{EASE}"
  end
end
