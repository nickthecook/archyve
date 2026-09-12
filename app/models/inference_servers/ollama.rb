module InferenceServers
  # A local or self-hosted Ollama. The provider Archyve started on, and the
  # only one where discovery can answer every question by itself.
  #
  # ## Two APIs, and why this class uses both
  #
  # RubyLLM does not speak native Ollama: RubyLLM::Providers::Ollama subclasses
  # the OpenAI provider and talks to Ollama's OpenAI-compatible endpoint. That
  # is the right choice for *inference* — one code path for chat and embedding
  # across every provider — but it is the wrong one for discovery, because
  # /v1/models reports nothing beyond an id, and RubyLLM fills the gap by
  # hardcoding the same capability list onto every model it returns. Through
  # that endpoint nomic-embed-text claims it can call functions.
  #
  # Ollama's own API has no such limitation, so discovery goes direct:
  #
  #   GET  /api/tags               what is pulled on this host
  #   POST /api/show {"model":…}   capabilities + model_info for one of them
  #
  # which is where kind, context window, embedding dimensions and tool support
  # all come from. Inference still goes through RubyLLM. This split is exactly
  # what the STI subclass is for — the provider-specific half stays here.
  class Ollama < InferenceServer
    # Discovery is many small calls to a host that is usually on the LAN, so it
    # gets a shorter leash than inference does.
    DISCOVERY_TIMEOUT = 30

    # What Ollama reports in `capabilities`, mapped to what Archyve stores.
    # "completion" is the marker for a generative model; "embedding" excludes
    # it. Anything reporting neither is left for a person to classify rather
    # than guessed at.
    EMBEDDING_CAPABILITY = "embedding".freeze
    CHAT_CAPABILITY = "completion".freeze
    TOOL_CAPABILITY = "tools".freeze

    # Stored as the root ("http://tensor:11434"), never the /v1 endpoint: the
    # native API lives at the root and RubyLLM's lives under /v1, so the root is
    # the only form both can be derived from. Pasting either works — the
    # normalizer below takes the suffix back off.
    before_validation :normalize_base_url

    validates :base_url, presence: true
    validate :base_url_must_be_an_http_url, if: -> { base_url.present? }

    def self.type_label = "Ollama"

    def self.description
      "A local or self-hosted Ollama. No key needed unless it sits behind a proxy."
    end

    def ruby_llm_provider = :ollama

    # RubyLLM talks to the OpenAI-compatible endpoint, which lives under /v1.
    def apply_config(config)
      config.ollama_api_base = "#{base_url}/v1"
      config.ollama_api_key = api_key if api_key.present?
    end

    # => Array<Discovered>, one per model pulled on the host.
    #
    # An /api/show that fails for one model doesn't lose it: it comes back with
    # kind nil and the import screen asks. Dropping it would make a model
    # invisible because a detail call timed out, which is a worse answer than
    # "you tell me".
    def available_models
      pulled_model_names.map do |name|
        details = show(name)
        details ? describe(name, details) : Discovered.new(name: name)
      end
    end

    private

    def pulled_model_names
      body = JSON.parse(connection.get("/api/tags").body)
      Array(body["models"]).filter_map { |model| model["name"].presence }
    end

    # Ollama wants a JSON body here. Assigning a String bypasses the connection's
    # url_encoded middleware, which would otherwise form-encode the hash.
    def show(name)
      response = connection.post("/api/show") do |request|
        request.headers["Content-Type"] = "application/json"
        request.body = { model: name }.to_json
      end
      JSON.parse(response.body)
    rescue StandardError => e
      Rails.logger.warn("ollama /api/show failed for #{name}: #{e.class}: #{e.message}")
      nil
    end

    def describe(name, details)
      capabilities = Array(details["capabilities"])
      info = details["model_info"] || {}
      family = details.dig("details", "family")

      kind = kind_from(capabilities)

      Discovered.new(
        name: name,
        kind: kind,
        context_window: info["#{family}.context_length"],
        # Only meaningful for an embedder. Chat models report embedding_length
        # too — it is their hidden size, nothing to do with a vector anyone
        # would store — so carrying it would put a confidently wrong number on
        # the import screen and into the row.
        dimensions: (info["#{family}.embedding_length"] if kind == :embedding),
        supports_tools: capabilities.include?(TOOL_CAPABILITY)
      )
    end

    # Embedding first: an embedder reports "embedding" and nothing else, while
    # a chat model reports "completion" alongside vision, audio and the rest.
    def kind_from(capabilities)
      return :embedding if capabilities.include?(EMBEDDING_CAPABILITY)
      return :chat if capabilities.include?(CHAT_CAPABILITY)

      nil
    end

    def connection
      @connection ||= Http.connection(base_url, timeout: DISCOVERY_TIMEOUT)
    end

    # Accepts the /v1 endpoint people have in OLLAMA_API_BASE today and stores
    # the root it implies, so both spellings lead to the same working server.
    def normalize_base_url
      return if base_url.blank?

      self.base_url = base_url.strip.sub(%r{/+\z}, "").sub(%r{/v1\z}, "")
    end

    def base_url_must_be_an_http_url
      uri = URI.parse(base_url)
      raise URI::InvalidURIError unless uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      errors.add(:base_url, "must be an http:// or https:// address")
    end
  end
end
