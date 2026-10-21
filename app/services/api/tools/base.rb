# frozen_string_literal: true

module Api
  module Tools
    Result = Data.define(:status, :body)

    # A chat tool, offered to a person or a script instead of a model: the same
    # name and arguments, answered as JSON with an HTTP status rather than as
    # prose. Each one names the chat tool it mirrors so the two can't drift.
    class Base
      class << self
        attr_reader :mirrored

        def mirrors(chat_tool) = @mirrored = chat_tool

        def describe(text) = @description = text

        # Arguments the API takes that a chat model doesn't, or narrower bounds on
        # the ones it does. Deep-merged over the chat tool's schema.
        def params(properties) = @extra_properties = properties.deep_stringify_keys

        def tool_name = mirrored::NAME

        def input_schema
          base = mirrored.params_schema_definition&.json_schema ||
            { "type" => "object", "properties" => {}, "additionalProperties" => false }

          base.except("strict").deep_merge("properties" => @extra_properties || {})
        end

        def definition = { name: tool_name, description: @description, input_schema: }

        def schemer = @schemer ||= JSONSchemer.schema(input_schema)
      end

      def initialize(user:)
        @user = user
      end

      # => Result
      def call(arguments)
        errors = self.class.schemer.validate(arguments).map { it["error"] }
        return error(:unprocessable_content, "invalid_arguments", errors.to_sentence) if errors.any?

        execute(**arguments.to_h.symbolize_keys)
      end

      private

      attr_reader :user

      def corpus(scope: nil) = Retrieval::Corpus.new(user:, scope:)

      def ok(body) = Result.new(status: :ok, body:)

      def error(status, code, message, **details)
        Result.new(status:, body: { error: code, message:, **details })
      end

      # Missing and unreadable are the same answer, as they are for the chat
      # tools: anything else counts what exists behind grants the caller lacks.
      def not_found(thing) = error(:not_found, "not_found", "No such #{thing}.")

      def document_ref(document) = { id: document.id, title: document.title }
    end
  end
end
