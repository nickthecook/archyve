# STI base class. Concrete servers live in app/models/inference_servers/*.
#
# An inference server is an endpoint plus whatever it takes to authenticate to
# it. It exists so a model never carries its own copy of a URL and a key: adding
# the fourth model on a host should not mean typing that host a fourth time.
#
# ## The provider contract
#
# A subclass implements three methods, and everything else in the app can then
# talk to it without knowing which provider it is:
#
#   #apply_config(config)  fill in this provider's keys on a RubyLLM config
#   #ruby_llm_provider     the provider symbol RubyLLM knows it by
#   #available_models      what the server says it can run, as Discovered
#
# All three are defined below and raise, rather than being left absent — an
# abstract method nobody wrote down is a contract you can only discover by
# reading the caller. Same reasoning, and the same error class, as Source.
class InferenceServer < ApplicationRecord
  # Raised when a subclass hasn't implemented the contract above. Not
  # NotImplementedError: that descends from ScriptError rather than
  # StandardError, so it would sail straight through the `rescue StandardError`
  # that #check! uses to record a failed connection, and the check would blow up
  # instead of reporting. Source documents the same trap.
  MissingImplementationError = Class.new(StandardError)

  # One model a server says it can run, as discovery sees it.
  #
  # Defined here rather than per subclass because it *is* the discovery
  # contract: the import screen reads these fields and nothing else, so every
  # provider describes its models the same way.
  #
  # Every field but the name is optional, because providers differ enormously in
  # how much they will tell you. **nil means "not reported" and is a real
  # answer** — `kind: nil` and `supports_tools: nil` both mean "ask a person",
  # which is different from `supports_tools: false`, a provider actually saying
  # the model can't call tools. Collapsing the two would put a confident wrong
  # claim on the screen, and "can't call tools" is a claim worth being right
  # about: it decides whether a model can do retrieval in chat at all.
  #
  # `skip_reason` is nil when the model is importable, and set when the server
  # has it but Archyve won't take it — a speech or image model has no honest
  # `kind` to be filed under. Deliberately the same word, and the same meaning,
  # as Source::Item#skip_reason: reported rather than filtered out, because a
  # model that quietly vanished from the list just sends someone looking for it.
  Discovered = Data.define(:name, :kind, :context_window, :dimensions, :supports_tools, :skip_reason) do
    def initialize(name:, kind: nil, context_window: nil, dimensions: nil, supports_tools: nil, skip_reason: nil)
      super
    end

    def skipped? = skip_reason.present?
  end

  # Concrete server types, in the order they should be offered in the UI.
  # Listed explicitly rather than found via `descendants` because Zeitwerk only
  # loads a subclass once something references it — in development that list is
  # empty until the class happens to have been touched. Source hit this first.
  TYPES = %w[InferenceServers::Ollama InferenceServers::OpenAI].freeze

  has_many :inference_models, dependent: :destroy

  encrypts :api_key

  validates :name, presence: true, uniqueness: true
  validate :api_key_must_be_present, if: -> { self.class.requires_api_key? }

  store_accessor :config, :base_url

  # There is deliberately no manageable_by/administrable_by scope trio here,
  # though Collection and Source both have one. Inference configuration is
  # system administration, not content: an operator who manages the HR
  # collection has no business pointing Archyve at a different LLM host. The
  # controllers gate on `require_role :admin` and there is nothing finer to
  # grant, so a per-object scope would only be ceremony.

  def self.type_label = name.demodulize
  def self.description = ""
  def self.user_creatable? = true

  # Whether the provider needs a key, and whether it needs an address. Drives
  # both validation and which fields the form renders, so the two can't drift.
  def self.requires_api_key? = false
  def self.requires_base_url? = true

  # Which variants of this provider are worth telling apart, as stored value =>
  # label. Empty for a provider that is only ever itself; see
  # InferenceServers::OpenAI, where one API has several servers behind it.
  def self.flavours = {}


  def self.creatable_types
    TYPES.map(&:constantize).select(&:user_creatable?)
  end

  def type_label = self.class.type_label
  def requires_api_key? = self.class.requires_api_key?
  def requires_base_url? = self.class.requires_base_url?
  def flavours = self.class.flavours

  # Extra request parameters a streaming chat with this server needs. Empty for
  # a provider that streams in a way Archyve can already read — see
  # InferenceServers::OpenAI#stream_params for the one that doesn't.
  def stream_params = {}

  # The per-call RubyLLM config for this server.
  #
  # RubyLLM's provider settings are global and single-slot — there is one
  # `config.ollama_api_base` for the whole process — so two Ollama hosts cannot
  # coexist through RubyLLM.configure. A Context carries its own dup of the
  # config, which is what lets each server speak for itself.
  #
  # It is also why config/initializers/ruby_llm.rb no longer configures
  # providers at all: an initializer runs before the database is readable, so
  # boot-time configuration could never have reflected these rows anyway.
  def llm_context
    RubyLLM.context { |config| apply_config(config) }
  end

  # Try the server and record what happened. Returns true on success.
  #
  # Synchronous, unlike Source's sync: this is one HTTP call with one outcome,
  # so making the admin wait a second beats making them refresh a page to find
  # out. Everything is rescued — the whole point is to report a bad URL or a
  # rejected key, and raising would turn a diagnostic into a 500.
  def check!
    models = available_models
    update!(
      last_checked_at: Time.current, last_check_status: "ok", last_check_error: nil,
      **learned_from_discovery
    )
    models
  rescue StandardError => e
    Rails.logger.error("inference server #{id} check failed: #{e.class}: #{e.message}")
    update!(last_checked_at: Time.current, last_check_status: "failed", last_check_error: "#{e.class}: #{e.message}")
    false
  end

  def checked? = last_checked_at.present?
  def reachable? = last_check_status == "ok"

  # --- passive health --------------------------------------------------------
  #
  # #check! is a deliberate probe. The two marks below are the same knowledge
  # arriving for free, from a chat turn or a search that talked to this server
  # anyway. Without them the badge only ever moves when an admin clicks Check,
  # so a server that dies *after* a successful check goes on claiming "reachable"
  # indefinitely — which is exactly the case where a wrong badge costs something.

  # How long an "it answered" claim stays fresh enough not to rewrite. This only
  # governs write volume, never what the page says: a status *change* is always
  # recorded immediately, so recovery still shows up at once.
  HEALTH_FRESH_FOR = 1.minute

  # How stale a status may get before the scheduler probes the server itself.
  CHECK_INTERVAL = 1.hour

  # What the tick should probe. Keyed off last_checked_at whatever wrote it, so a
  # server chat or search is already exercising is never probed: traffic *is* the
  # check, and discovery is far from free — against Ollama it is one HTTP call
  # per model pulled on the host, and against a remote provider it spends rate
  # limit to learn what the last chat turn already proved.
  #
  # Failed servers stay in scope on purpose: for an idle host the probe is the
  # only thing that can ever turn it green again.
  scope :due_for_check, -> {
    where(last_checked_at: nil).or(where(last_checked_at: ..CHECK_INTERVAL.ago))
  }

  # How much of an exception message is worth keeping on the row.
  CHECK_ERROR_LIMIT = 500

  # The exceptions that mean *this server didn't answer*, and so the only ones
  # allowed to turn the badge red.
  #
  # Deliberately narrower than Ingestion::Outcome's "unreachable", which answers
  # a different question — "will re-uploading this document help?" — and rightly
  # says no for a rate limit or an overloaded host. Here the question is "is the
  # host up?", and a server that replied "slow down" or "I'm busy" demonstrably
  # is. Rejected credentials are likewise someone's Settings entry being wrong
  # rather than an outage, so they leave the badge green on purpose: the server
  # is reachable, the configuration isn't.
  UNREACHABLE_ERRORS = [
    Faraday::ConnectionFailed,
    Faraday::TimeoutError,
    RubyLLM::ServerError,
    RubyLLM::ServiceUnavailableError
  ].freeze

  def self.unreachable_error?(error) = UNREACHABLE_ERRORS.any? { error.is_a?(it) }

  # update_columns rather than update!, in both marks below: these run on a
  # request path, one of them inside a rescue, and a row that has gone invalid
  # for an unrelated reason — a cleared API key — would raise out of the very
  # handler that exists to report trouble. Same trap MissingImplementationError
  # documents at the top of this file. It also leaves updated_at alone, which
  # should keep meaning "somebody changed the configuration".
  def mark_reachable!
    return if reachable? && last_checked_at&.after?(HEALTH_FRESH_FOR.ago)

    update_columns(last_checked_at: Time.current, last_check_status: "ok", last_check_error: nil)
  end

  # Unthrottled, unlike the success mark: failures are rare, and consecutive ones
  # can each carry a different message worth showing.
  def mark_unreachable!(error)
    update_columns(
      last_checked_at: Time.current,
      last_check_status: "failed",
      last_check_error: "#{error.class}: #{error.message}".truncate(CHECK_ERROR_LIMIT)
    )
  end

  # --- provider contract (see the class comment) -----------------------------

  def apply_config(_config)
    raise MissingImplementationError, "#{self.class.name} must implement #apply_config"
  end

  def ruby_llm_provider
    raise MissingImplementationError, "#{self.class.name} must implement #ruby_llm_provider"
  end

  # => Array<Discovered>
  def available_models
    raise MissingImplementationError, "#{self.class.name} must implement #available_models"
  end

  private

  # What discovery learned about the *server* rather than its models, written
  # with the health mark so a check stays one write. Read only after
  # #available_models has run, which is what fills it in.
  def learned_from_discovery = {}

  def api_key_must_be_present
    errors.add(:api_key, "is required for #{self.class.type_label}") if api_key.blank?
  end
end
