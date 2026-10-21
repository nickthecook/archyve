module ApiCalls
  # What the index offers to filter on, and how each filter narrows the list.
  # Adding one is a line in FILTERS.
  #
  # A value that isn't on offer is ignored rather than refused: these arrive as
  # a URL anyone can edit, and a host whose last call has since been swept is a
  # stale bookmark, not an error worth a page about.
  class Listing
    Filter = Data.define(:param, :label, :options, :narrow)

    FILTERS = [
      Filter.new(param: "kind", label: "Kind", options: -> { ApiCall::KINDS },
        narrow: ->(rows, value) { rows.of_kind(value) }),
      # `host` is url_for's own option for the host of the URL it builds, so a
      # link to a filtered list needs `path(params: { host: … })`.
      Filter.new(param: "host", label: "Host", options: -> { ApiCall.hosts },
        narrow: ->(rows, value) { rows.at_host(value) }),
      Filter.new(param: "direction", label: "Direction", options: -> { %w[incoming outgoing] },
        narrow: ->(rows, value) { rows.public_send(value) }),
      Filter.new(param: "user", label: "User",
        options: -> { User.where(id: ApiCall.select(:user_id)).order(:email_address).pluck(:email_address) },
        narrow: ->(rows, value) { rows.where(user: User.where(email_address: value)) }),
      # By prefix: names needn't be unique, and the prefix is what a person sees
      # beside each key on their account page.
      Filter.new(param: "key", label: "Key",
        options: -> { ApiKey.where(id: ApiCall.select(:api_key_id)).order(:token_prefix).pluck(:token_prefix) },
        narrow: ->(rows, value) { rows.where(api_key: ApiKey.where(token_prefix: value)) })
    ].freeze

    def initialize(params)
      @params = params
    end

    # Unordered: Page orders what it pages, and ordering it twice would
    # only mean the second one winning silently.
    def page = Page.of(rows, after: @params["after"], before: @params["before"])

    # What the pager has to carry so that paging doesn't drop the filters.
    def query = FILTERS.to_h { [it.param, selected(it)] }.compact

    def facets
      FILTERS.map do |filter|
        Views::Admin::Facet.new(
          label: filter.label, param: filter.param,
          options: options_for(filter), selected: selected(filter)
        )
      end
    end

    private

    def rows
      FILTERS.reduce(ApiCall.all) { |rows, filter| narrow(filter, rows) }
    end

    def narrow(filter, rows)
      value = selected(filter)
      value ? filter.narrow.call(rows, value) : rows
    end

    def selected(filter)
      value = @params[filter.param].presence
      value if options_for(filter).include?(value)
    end

    def options_for(filter)
      @options ||= {}
      @options[filter.param] ||= filter.options.call
    end
  end
end
