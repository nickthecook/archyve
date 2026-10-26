# frozen_string_literal: true

# One filter an index offers: a labelled set of values, and whichever of them is
# in effect. An option is a value, or a [value, label] pair where the stored
# value doesn't read well on its own.
class Views::Admin::Facet
  attr_reader :label, :param, :options, :selected

  def initialize(label:, param:, options:, selected: nil, blank: nil, defaulted: false)
    @label = label
    @param = param
    @options = options
    @selected = selected
    @blank = blank
    @defaulted = defaulted
  end

  def any? = @options.any?
  def blank_label = @blank || "Any #{label.downcase}"

  # Whether leaving the param out turns this filter on, so clearing it has to
  # send it blank.
  def defaulted? = @defaulted
end
