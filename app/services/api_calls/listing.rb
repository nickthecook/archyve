module ApiCalls
  class Listing < FilteredListing
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

    private

    def base = ApiCall.all
  end
end
