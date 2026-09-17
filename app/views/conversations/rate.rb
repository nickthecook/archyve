# frozen_string_literal: true

# Generation speed, next to the thing that was generated.
#
# One component rather than a format string at each call site, because the
# collapsed thinking row and the turn's attribution are showing the same fact
# and have to round it the same way — two spellings of one number read as two
# different measurements.
#
# It brings its own separator, on whichever side faces what it sits next to:
# `:before` when it follows something, `:after` when it leads. Nothing is
# rendered when there is no rate — an old turn, or a segment too short to have a
# span — and a dangling "·" left behind by a caller that forgot to check would
# be worse than the number missing.
class Views::Conversations::Rate < Components::Base
  def initialize(rate, separator: :before)
    @rate = rate
    @separator = separator
  end

  # The space is its own text node, outside the span, so it is the only place
  # this can break. On a phone the thinking row runs out of width and wraps
  # there, putting the rate and its "·" whole onto one line; left inside the
  # span there'd be nowhere to break and the row would push the page sideways
  # instead, which the narrow-viewport rules don't allow.
  def view_template
    return if @rate.nil?

    whitespace if @separator == :before
    span(class: "whitespace-nowrap text-faint tabular-nums") { punctuated }
    whitespace if @separator == :after
  end

  private

  def punctuated = @separator == :before ? "· #{formatted}" : "#{formatted} ·"

  # "tok/s", not "tokens/s": this sits at the end of a row that already has
  # words in it, and on a phone the row has nowhere to put six more characters.
  #
  # A decimal only below 10, where rounding to whole tokens is the difference
  # between 4 and 5 a second. Above that the digit is noise that jitters every
  # time the same model answers.
  def formatted = "#{@rate < 10 ? @rate.round(1) : @rate.round} tok/s"
end
