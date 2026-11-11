module InferenceServers
  # Azure OpenAI or AI Foundry, through the v1 API (`/openai/v1`).
  #
  # Requests are addressed to deployments, and Azure's data plane can't list
  # them: its /models reports the catalogue the resource could deploy. So
  # discovery is one deployment at a time — see #describe_deployment.
  class Azure < OpenAI
    PROBE_PROMPT = "Reply with OK.".freeze

    validates :base_url, presence: true, format: { with: %r{\Ahttps://}i, message: "must be an https:// address" }

    def self.type_label = "Azure"
    def self.description = "Azure OpenAI or AI Foundry, through the v1 API."
    def self.requires_base_url? = true
    def self.lists_models? = false
    def self.flavours = {}
    def self.base_url_placeholder = "https://my-resource.openai.azure.com"

    def self.base_url_hint
      "The resource endpoint. Pasting a deployment's Target URI works too — Archyve keeps only the host."
    end

    def ruby_llm_provider = :azure

    def apply_config(config)
      config.azure_api_base = "#{base_url}/openai/v1"
      config.azure_api_key = api_key
    end

    # Reachability only: proves the address and key without spending tokens.
    def available_models
      provider.connection.get("models")
      []
    end

    # => Discovered, by asking the deployment to do its job. An embedding
    # deployment refuses a chat request with a 400, which is the cue to embed.
    def describe_deployment(name)
      describe_chat(name, llm_context.chat(model: name, provider: :azure, assume_model_exists: true).ask(PROBE_PROMPT))
    rescue RubyLLM::BadRequestError
      vectors = llm_context.embed(PROBE_PROMPT, model: name, provider: :azure, assume_model_exists: true).vectors
      Discovered.new(name:, kind: :embedding, dimensions: vectors.size)
    end

    private

    def learned_from_discovery = {}

    # The response names the model behind the deployment ("gpt-4o-2024-11-20"
    # behind "prod-chat"), which is what RubyLLM's patterns can recognise.
    def describe_chat(name, response)
      family = family_for(response.model_id.to_s)
      return Discovered.new(name:, kind: :chat) if family == UNKNOWN_FAMILY

      capabilities = RubyLLM::Providers::OpenAI::Capabilities
      Discovered.new(
        name:,
        kind: :chat,
        context_window: capabilities.context_window_for(response.model_id),
        supports_tools: capabilities.supports_functions?(response.model_id)
      )
    end

    def normalize_base_url
      return if base_url.blank?

      self.base_url = base_url.strip.sub(/[?#].*\z/, "").sub(%r{/(openai|api|models)(/.*)?\z}, "").sub(%r{/+\z}, "")
    end
  end
end
