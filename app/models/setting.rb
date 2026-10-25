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
    # Which chat model a new conversation starts on. An id rather than a flag on
    # inference_models: exactly one model is the default, and a column true on
    # one row needed a partial unique index, a demote-the-incumbent callback and
    # a validation to say so. Nil means "whatever InferenceModel.default_chat
    # falls back to", which is also what a stale id resolves to.
    "chat.default_model_id" => Definition.new(
      default: nil,
      type: :integer,
      description: "The chat model a new conversation starts on, by id. Unset means the first " \
        "usable one."
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
    ),
    # Apart from the outbound switch so a provider can be debugged in production
    # without recording what people do through the API.
    "debug.record_incoming_api_calls" => Definition.new(
      default: -> { ActiveModel::Type::Boolean.new.cast(ENV.fetch("ARCHYVE_RECORD_INCOMING_API_CALLS", nil)) || false },
      type: :boolean,
      description: "Record requests to Archyve's own API, and its responses, to the api_calls table."
    ),
    # Blank is a choice rather than a reset: a logo that already carries the
    # name shouldn't have it printed beside it twice.
    "brand.name" => Definition.new(
      default: "ARCHYVE",
      type: :string,
      description: "The name shown beside the logo. Blank shows the logo alone."
    ),
    "brand.logo" => Definition.new(
      default: nil,
      type: :image,
      description: "Shown in place of the triangle mark."
    ),
    "brand.ask_placeholder" => Definition.new(
      default: "Consult the archive",
      type: :string,
      description: "Shown in the box on the landing page before anyone types."
    ),
    "brand.chat_placeholder" => Definition.new(
      default: "What do you want to know?",
      type: :string,
      description: "Shown in the box on Chat before anyone types."
    )
  }.freeze

  # No SVG: Active Storage serves it as application/octet-stream, which an
  # <img> won't render.
  IMAGE_TYPES = %w[image/png image/jpeg image/webp].freeze

  has_one_attached :file

  validates :key, presence: true, uniqueness: true, inclusion: { in: DEFINITIONS.keys }
  validates :file, content_type: IMAGE_TYPES, size: { less_than: 2.megabytes }

  class << self
    def [](key)
      definition = definition!(key)
      row = find_by(key:)
      row ? cast(row, definition.type) : definition.default_value
    end

    def []=(key, value)
      definition = definition!(key)
      find_or_initialize_by(key:).update!(definition.type == :image ? { file: value } : { value: value.to_s })
    end

    # Named readers, so callers don't pass strings around and typos fail at
    # boot rather than at retrieval time.
    def chat_result_limit = self["chat.result_limit"]
    def chat_max_search_rounds = self["chat.max_search_rounds"]
    def chat_max_read_rounds = self["chat.max_read_rounds"]
    def chat_max_listing_rounds = self["chat.max_listing_rounds"]
    def chat_instance_purpose = self["chat.instance_purpose"]
    def chat_default_model_id = self["chat.default_model_id"]
    def record_api_calls? = self["debug.record_api_calls"]
    def record_incoming_api_calls? = self["debug.record_incoming_api_calls"]
    def brand_name = self["brand.name"]
    def brand_logo = self["brand.logo"]
    def brand_ask_placeholder = self["brand.ask_placeholder"]
    def brand_chat_placeholder = self["brand.chat_placeholder"]

    # Back to the declared default. `[]=` only ever writes, so without this a
    # setting that has been set has no way back to "unset" — and "" would cast
    # to 0, which for an id is a row that doesn't exist.
    def clear(key)
      definition!(key)
      where(key:).destroy_all
    end

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

    def cast(row, type)
      case type
      when :integer then row.value.to_i
      when :boolean then ActiveModel::Type::Boolean.new.cast(row.value)
      when :image then row.file if row.file.attached?
      else row.value
      end
    end
  end
end
