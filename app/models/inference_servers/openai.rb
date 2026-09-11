module InferenceServers
  # OpenAI, or anything that speaks its API — vLLM, LiteLLM, LM Studio, a
  # gateway. Leave the address blank for OpenAI itself; set it to reach one of
  # the others.
  #
  # Discovery here goes through RubyLLM rather than direct HTTP, the opposite of
  # Ollama. /v1/models is all this API offers, so there is nothing to gain by
  # bypassing the gem — and RubyLLM's own model registry fills in context
  # windows for the models it recognises, which is more than the endpoint says.
  #
  # What it cannot report is which models are embedders: an OpenAI-compatible
  # /v1/models is a list of ids and nothing more. Discovered#kind comes back nil
  # and the import screen asks. That isn't a shortcoming worth coding around —
  # the endpoint genuinely doesn't know.
  class OpenAI < InferenceServer
    before_validation :normalize_base_url

    validates :api_key, presence: true

    def self.type_label = "OpenAI"

    def self.description
      "OpenAI, or any endpoint that speaks its API — vLLM, LiteLLM, a gateway."
    end

    # An address is optional here, unlike Ollama: blank means OpenAI proper.
    def self.requires_base_url? = false
    def self.requires_api_key? = true

    def ruby_llm_provider = :openai

    def apply_config(config)
      config.openai_api_key = api_key
      config.openai_api_base = base_url if base_url.present?
    end

    # => Array<Discovered>. No kind — see the class comment.
    def available_models
      provider.list_models.map do |info|
        Discovered.new(name: info.id, context_window: info.context_window)
      end
    end

    private

    def provider
      RubyLLM::Provider.resolve(ruby_llm_provider).new(llm_context.config)
    end

    def normalize_base_url
      self.base_url = base_url.strip.sub(%r{/+\z}, "") if base_url.present?
    end
  end
end
