# frozen_string_literal: true

module Inference
  # The servers and models ARCHYVE_INFERENCE declares. Inference::Provisioner
  # reconciles the database against it; see docs/architecture.md.
  #
  # Two lists, because they answer different questions: `servers` holds the
  # entries good enough to write, and `declared` every name the variable
  # mentions at all. An entry with a typo is skipped, but it still counts as
  # declared, so a mistake in the env can't de-provision what it meant to keep.
  class Spec
    VAR = "ARCHYVE_INFERENCE"
    DEFAULT_CHAT_VAR = "ARCHYVE_DEFAULT_CHAT_MODEL"

    TYPES = {
      "ollama" => "InferenceServers::Ollama",
      "openai" => "InferenceServers::OpenAI",
      "azure" => "InferenceServers::Azure"
    }.freeze

    SERVER_KEYS = %w[name type base_url api_key_env flavour models].freeze
    MODEL_KEYS = %w[name kind display_name supports_tools dimensions protocol].freeze

    ParseError = Class.new(StandardError)

    Server = Data.define(:name, :klass, :attributes, :models)
    Model = Data.define(:name, :attributes)

    attr_reader :servers, :declared, :errors

    # "server/model", split at the first slash: model ids often carry one of
    # their own (meta-llama/Llama-3.1-8B), server names don't.
    def self.default_chat_ref(env = ENV)
      parts = env.fetch(DEFAULT_CHAT_VAR, "").split("/", 2)
      parts if parts.size == 2 && parts.all?(&:present?)
    end

    def self.load(env = ENV) = new(env.fetch(VAR, nil), env)

    def initialize(raw, env)
      @env = env
      @servers = []
      @declared = {}
      @errors = []
      return if raw.blank?

      entries = JSON.parse(raw)
      raise ParseError, "#{VAR} must be a JSON array of servers" unless entries.is_a?(Array)

      entries.each { read_server(it) }
    rescue JSON::ParserError => e
      raise ParseError, "#{VAR} isn't valid JSON: #{e.message}"
    end

    private

    def read_server(entry)
      return @errors << "#{VAR}: every server must be an object with a name" unless named?(entry)

      name = entry["name"]
      models = Array(entry["models"]).select { named?(it) }
      @declared[name] = models.map { it["name"] }

      klass = TYPES[entry["type"]]&.constantize
      problems = server_problems(entry, klass)
      return @errors << "server #{name}: #{problems.to_sentence}" if problems.any?

      @servers << Server.new(name:, klass:, attributes: server_attributes(entry, klass), models: read_models(name, entry))
    end

    def server_problems(entry, klass)
      problems = unknown_keys(entry, SERVER_KEYS)
      problems << "type must be one of #{TYPES.keys.join(', ')}" if klass.nil?
      problems << "flavour isn't a setting of #{entry['type']}" if entry["flavour"] && klass&.flavours&.none?
      problems << "models must be an array" unless entry.fetch("models", []).is_a?(Array)
      if (key_var = entry["api_key_env"]) && @env[key_var].blank?
        problems << "api_key_env names #{key_var}, which isn't set"
      end
      problems
    end

    # Every setting written, absent ones as nil, so removing a line from the
    # env clears it rather than leaving the last value behind.
    def server_attributes(entry, klass)
      attributes = { base_url: entry["base_url"], api_key: entry["api_key_env"]&.then { @env[it] } }
      attributes[:flavour] = entry["flavour"] if klass.flavours.any?
      attributes
    end

    def read_models(server_name, entry)
      entry.fetch("models", []).filter_map do |model|
        problems = named?(model) ? unknown_keys(model, MODEL_KEYS) : ["every model must be an object with a name"]
        if problems.any?
          @errors << "server #{server_name}: #{problems.to_sentence}"
          next
        end

        Model.new(name: model["name"], attributes: model_attributes(model))
      end
    end

    # A chat model is declared to be used for chat, which in Archyve means
    # calling tools — the same reading the import picker gives a ticked row.
    def model_attributes(model)
      kind = model.fetch("kind", "chat")
      {
        kind:,
        display_name: model["display_name"],
        supports_tools: model.fetch("supports_tools", kind == "chat"),
        dimensions: model["dimensions"],
        protocol: model["protocol"]
      }
    end

    def unknown_keys(entry, allowed)
      (entry.keys - allowed).map { "#{it} isn't a recognised setting" }
    end

    def named?(entry) = entry.is_a?(Hash) && entry["name"].is_a?(String) && entry["name"].present?
  end
end
