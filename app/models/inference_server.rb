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
  # provider describes its models the same way. Everything but the name is
  # optional, because providers differ enormously in how much they will tell
  # you — `kind: nil` means "this provider can't say", and the human classifies
  # it. That is a real answer, not a failure.
  Discovered = Data.define(:name, :kind, :context_window, :dimensions, :supports_tools) do
    def initialize(name:, kind: nil, context_window: nil, dimensions: nil, supports_tools: false)
      super
    end
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

  def self.creatable_types
    TYPES.map(&:constantize).select(&:user_creatable?)
  end

  def type_label = self.class.type_label
  def requires_api_key? = self.class.requires_api_key?
  def requires_base_url? = self.class.requires_base_url?

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
    update!(last_checked_at: Time.current, last_check_status: "ok", last_check_error: nil)
    models
  rescue StandardError => e
    Rails.logger.error("inference server #{id} check failed: #{e.class}: #{e.message}")
    update!(last_checked_at: Time.current, last_check_status: "failed", last_check_error: "#{e.class}: #{e.message}")
    false
  end

  def checked? = last_checked_at.present?
  def reachable? = last_check_status == "ok"

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

  def api_key_must_be_present
    errors.add(:api_key, "is required for #{self.class.type_label}") if api_key.blank?
  end
end
