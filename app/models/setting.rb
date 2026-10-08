# A tunable an admin can change without a deploy.
#
# Deliberately not a general key/value store: every setting is declared in
# DEFINITIONS with a default and a type, and reading an undeclared key raises.
# A settings table that accepts anything becomes a junk drawer nobody can audit,
# and the defaults have to live in code anyway — a fresh install has no rows.
#
# A row appears only when someone changes a value away from its default, so
# "what is this set to" and "has anyone touched this" stay separable.
class Setting < ApplicationRecord
  UnknownSetting = Class.new(StandardError)

  Definition = Data.define(:default, :type, :description) do
    # A callable default is resolved on read rather than when this file loads,
    # which is what lets one come from the environment: DEFINITIONS is built at
    # boot, and a default baked in then is a snapshot nothing can correct.
    def default_value = default.respond_to?(:call) ? default.call : default
  end

  DEFINITIONS = {
    # How many retrieved chunks the chat model is given per tool call. A count
    # is a stand-in for the real constraint, which is tokens: chunks vary in
    # size, and what actually matters is how much of the chat model's context
    # window retrieval is allowed to fill. Revisit this as a budget derived
    # from InferenceModel#context_window rather than a number typed by hand.
    "chat.result_limit" => Definition.new(
      default: 6,
      type: :integer,
      description: "How many search results the chat model sees per retrieval."
    ),
    # Each of the three below caps one tool, not the turn — a model that has
    # searched to its limit can still read. See Tools::Base#over_budget?.
    "chat.max_search_rounds" => Definition.new(
      default: -> { positive_integer_env("ARCHYVE_CHAT_MAX_SEARCH_ROUNDS", 2) },
      type: :integer,
      description: "How many times the model may search the archive in one turn."
    ),
    # Looser than search: how many documents are worth reading is set by what
    # the search found, not by the model going in circles.
    "chat.max_read_rounds" => Definition.new(
      default: -> { positive_integer_env("ARCHYVE_CHAT_MAX_READ_ROUNDS", 4) },
      type: :integer,
      description: "How many documents the model may read in one turn."
    ),
    # Looser again: a listing costs no embedding call and no vector scan, and
    # finding one's way around takes more steps than answering.
    "chat.max_listing_rounds" => Definition.new(
      default: -> { positive_integer_env("ARCHYVE_CHAT_MAX_LISTING_ROUNDS", 4) },
      type: :integer,
      description: "How many times the model may list part of the archive in one turn."
    ),
    # Appended to the system prompt after Archyve's own instructions — see
    # Chat::Instructions. Free text because "who is this for" doesn't fit a
    # number or a boolean, and a blank default means a fresh install injects
    # nothing rather than an empty sentence.
    "chat.instance_purpose" => Definition.new(
      default: "",
      type: :string,
      description: "What this instance is for and who it's answering. Appended to the system prompt " \
        "on every chat, after Archyve's own instructions. A sentence or two, not a policy document " \
        "— it should say who's using this instance and what they need from it, not how to cite " \
        "sources or search the archive, which the base prompt already covers."
    ),
    # Recording every outbound inference call to api_calls — see ApiCall.
    # ARCHYVE_RECORD_API_CALLS sets the default, so a deployment can boot with
    # recording already on; a row overrides it, which is what lets it be
    # switched on against a server that is already misbehaving.
    "debug.record_api_calls" => Definition.new(
      default: -> { ActiveModel::Type::Boolean.new.cast(ENV.fetch("ARCHYVE_RECORD_API_CALLS", nil)) || false },
      type: :boolean,
      description: "Record outbound inference requests and responses, with their bodies, to the " \
        "api_calls table. For debugging a provider that isn't behaving — it writes a row per chat " \
        "and per model discovery call, and those rows are swept once they are a few days old."
    )
  }.freeze

  validates :key, presence: true, uniqueness: true, inclusion: { in: DEFINITIONS.keys }

  class << self
    def [](key)
      definition = definition!(key)
      row = find_by(key:)
      row ? cast(row.value, definition.type) : definition.default_value
    end

    def []=(key, value)
      definition!(key)
      find_or_initialize_by(key:).update!(value: value.to_s)
    end

    # Named readers, so callers don't pass strings around and typos fail at
    # boot rather than at retrieval time.
    def chat_result_limit = self["chat.result_limit"]
    def chat_max_search_rounds = self["chat.max_search_rounds"]
    def chat_max_read_rounds = self["chat.max_read_rounds"]
    def chat_max_listing_rounds = self["chat.max_listing_rounds"]
    def chat_instance_purpose = self["chat.instance_purpose"]
    def record_api_calls? = self["debug.record_api_calls"]

    # The settings that are a single on/off, and so can be flipped in place
    # from the settings index rather than needing a page and a Save button.
    def toggles = DEFINITIONS.select { |_key, definition| definition.type == :boolean }

    private

    # Anything unset or unparseable falls back to the default: `.to_i` alone
    # turns a typo into 0, which for a round budget is a tool the model can
    # never call.
    def positive_integer_env(name, fallback)
      value = ENV.fetch(name, nil).to_i
      value.positive? ? value : fallback
    end

    def definition!(key)
      DEFINITIONS.fetch(key) { raise UnknownSetting, "no such setting: #{key.inspect}" }
    end

    def cast(value, type)
      case type
      when :integer then value.to_i
      when :boolean then ActiveModel::Type::Boolean.new.cast(value)
      else value
      end
    end
  end
end
