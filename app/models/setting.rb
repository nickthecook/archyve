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

  Definition = Data.define(:default, :type, :description)

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
    # How many times the model may call the retrieval tool in one turn before
    # Archyve stops answering it. A guard against a confused model looping, not
    # a quality dial — two rounds is enough to search, read, and search again.
    "chat.max_tool_rounds" => Definition.new(
      default: 2,
      type: :integer,
      description: "How many times the model may search the archive in one turn."
    ),
    # The same guard for walking the archive, and looser: a listing costs no
    # embedding call and no vector scan, and a model finding its way around
    # genuinely needs more than two steps — list the collections, then list one,
    # then list another. Still capped, because a model walking list_documents
    # across every collection it was shown is a real failure mode.
    "chat.max_listing_rounds" => Definition.new(
      default: 4,
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
    )
  }.freeze

  validates :key, presence: true, uniqueness: true, inclusion: { in: DEFINITIONS.keys }

  class << self
    def [](key)
      definition = definition!(key)
      row = find_by(key:)
      row ? cast(row.value, definition.type) : definition.default
    end

    def []=(key, value)
      definition!(key)
      find_or_initialize_by(key:).update!(value: value.to_s)
    end

    # Named readers, so callers don't pass strings around and typos fail at
    # boot rather than at retrieval time.
    def chat_result_limit = self["chat.result_limit"]
    def chat_max_tool_rounds = self["chat.max_tool_rounds"]
    def chat_max_listing_rounds = self["chat.max_listing_rounds"]
    def chat_instance_purpose = self["chat.instance_purpose"]

    private

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
