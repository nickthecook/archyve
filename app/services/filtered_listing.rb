# What a filtered admin list offers, and how each filter narrows it. A subclass
# names its FILTERS and the rows they narrow; adding a filter is a line there.
#
# A value that isn't on offer is ignored rather than refused: these arrive as
# a URL anyone can edit, and an option that has since gone is a stale bookmark,
# not an error worth a page about.
class FilteredListing
  # `default` applies when the param is absent; `blank` names the choice that
  # turns the filter off.
  Filter = Data.define(:param, :label, :options, :narrow, :default, :blank) do
    def initialize(default: nil, blank: nil, **) = super
  end

  def initialize(params)
    @params = params
  end

  # Unordered: Page orders what it pages, and ordering it twice would
  # only mean the second one winning silently.
  def page = Page.of(rows, after: @params["after"], before: @params["before"], per: per_page)

  # What the pager has to carry so that paging doesn't drop the filters. A
  # default the reader turned off is carried as blank, or the next page would
  # turn it back on.
  def query
    self.class::FILTERS.to_h { [it.param, selected(it) || (it.default && "")] }.compact
  end

  def facets
    self.class::FILTERS.map do |filter|
      Views::Admin::Facet.new(
        label: filter.label, param: filter.param, blank: filter.blank, defaulted: !filter.default.nil?,
        options: options_for(filter), selected: selected(filter)
      )
    end
  end

  def rows
    self.class::FILTERS.reduce(base) { |rows, filter| narrow(filter, rows) }
  end

  private

  def base = raise(NotImplementedError)
  def per_page = Page::PER_PAGE

  def narrow(filter, rows)
    value = selected(filter)
    value ? filter.narrow.call(rows, value) : rows
  end

  def selected(filter)
    value = @params.key?(filter.param) ? @params[filter.param].presence : filter.default
    value if option_values(filter).include?(value)
  end

  def option_values(filter) = options_for(filter).map { Array(it).first }

  def options_for(filter)
    @options ||= {}
    @options[filter.param] ||= filter.options.call
  end
end
