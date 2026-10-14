# One outbound HTTP call, recorded so a provider that isn't behaving can be
# inspected after the fact — what Archyve actually sent, and what came back on
# the wire rather than after a client library has interpreted it.
#
# Written by ApiCalls::Recorder, which sits in the Faraday stack of both RubyLLM
# and Http.connection but stays inert unless recording is switched on. See
# Setting's "debug.record_api_calls" for how that happens.
class ApiCall < ApplicationRecord
  # What a call was for. An allowlist rather than a label on everything — see
  # ApiCalls::Kind for what is deliberately not recorded.
  KINDS = %w[chat discovery].freeze

  # Rows are debugging exhaust carrying request and response bodies, so they
  # expire on a timer. ApiCalls::SweepExpiredJob does the deleting.
  RETENTION = 3.days

  # The lowest number that can be an HTTP status, and so the boundary between
  # "something answered" and the codes below.
  LOWEST_HTTP_STATUS = 100

  # Why nothing answered. response_code doubles as the outcome of a call: a real
  # status when the server replied, and one of these when it never did — which
  # is most of what goes wrong with a self-hosted inference server, and exactly
  # what a bare nil could not tell apart.
  #
  # These are persisted values. Add to the map; never renumber it.
  NO_RESPONSE = {
    connection_refused: 1,
    host_unreachable: 2,
    dns_failure: 3,
    timeout: 4,
    ssl_failure: 5,
    # Faraday said the connection failed but not why.
    connection_failed: 6,
    unknown: 9
  }.freeze

  # Usually the turn a chat call was answering, which is the difference between
  # a list of calls and being able to ask what one conversation did.
  belongs_to :traceable, polymorphic: true, optional: true

  validates :kind, inclusion: { in: KINDS }

  scope :expired, -> { where(created_at: ...RETENTION.ago) }
  scope :recent, -> { order(created_at: :desc) }
  scope :of_kind, ->(kind) { where(kind:) }

  # The host is inside the URL rather than a column of its own, so both of these
  # go through the URLs themselves: one parser decides what a host is, and the
  # filter can't disagree with the list of hosts it offers. However many calls
  # there are, the distinct URLs are a handful — an endpoint per server.
  def self.urls = unscope(:order).distinct.pluck(:url)

  def self.hosts = urls.filter_map { host_in(it) }.uniq.sort

  def self.at_host(host)
    where(url: urls.select { host_in(it) == host })
  end

  def self.host_in(url)
    URI.parse(url).host
  rescue URI::InvalidURIError
    nil
  end

  # Both exclude a null response_code, which means recording never got as far as
  # an outcome either way.
  scope :answered, -> { where(response_code: LOWEST_HTTP_STATUS..) }
  scope :unanswered, -> { where(response_code: ...LOWEST_HTTP_STATUS) }

  # Deliberately not a Rails enum: `enum` claims the whole column and raises on
  # any value outside its map, which would reject every real HTTP status. This
  # gives the same predicates and scopes over a column that also holds 200.
  NO_RESPONSE.each do |name, code|
    scope name, -> { where(response_code: code) }
    define_method(:"#{name}?") { response_code == code }
  end

  class << self
    # Rescued because this is asked on every outbound call, including ones made
    # before the schema is loaded — a missing settings table must not take down
    # the request it is only trying to observe.
    def recording?
      Setting.record_api_calls?
    rescue StandardError
      false
    end

    def no_response_code_for(error)
      NO_RESPONSE.fetch(no_response_kind(error), NO_RESPONSE[:unknown])
    end

    private

    def no_response_kind(error)
      case error
      when Faraday::TimeoutError, Timeout::Error, Errno::ETIMEDOUT then :timeout
      when Faraday::SSLError then :ssl_failure
      when Faraday::ConnectionFailed then connection_failure_kind(error)
      else :unknown
      end
    end

    # Faraday::ConnectionFailed is a wrapper, and what actually happened is the
    # exception inside it — nil when Faraday raised with a bare string.
    def connection_failure_kind(error)
      case error.wrapped_exception
      when Errno::ECONNREFUSED then :connection_refused
      when Errno::EHOSTUNREACH, Errno::ENETUNREACH then :host_unreachable
      when SocketError then :dns_failure
      else :connection_failed
      end
    end
  end

  def host = self.class.host_in(url)

  def answered? = response_code.present? && response_code >= LOWEST_HTTP_STATUS

  # The symbol naming why nothing answered, or nil when something did.
  def failure
    return nil if response_code.nil? || answered?

    NO_RESPONSE.key(response_code) || :unknown
  end
end
