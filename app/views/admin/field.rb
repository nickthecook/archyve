# frozen_string_literal: true

# A labelled value read off a record: one column of an admin table, one row of an
# admin detail list. The block returns a String to be printed, or renders its own
# markup — a badge or a link can't be a String.
class Views::Admin::Field
  attr_reader :label

  def initialize(label, numeric: false, mono: numeric, &value)
    @label = label
    @numeric = numeric
    @mono = mono
    @value = value
  end

  def numeric? = @numeric
  def mono? = @mono

  def value_for(record) = @value.call(record)
end
