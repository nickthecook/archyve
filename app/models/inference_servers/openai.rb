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
    # What RubyLLM calls tool support in a Model::Info's capabilities, and the
    # family it reports for an id it has no pattern for.
    FUNCTION_CALLING = "function_calling".freeze
    UNKNOWN_FAMILY = "other".freeze

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
    #
    # Context window and tool support are worth taking from RubyLLM, but only
    # where it actually recognises the model. For anything else its capability
    # module falls back to defaults — 4,096 tokens and no function calling —
    # and those are pattern-matching guesses, not something the endpoint said.
    # Reported as nil so the import screen asks instead of writing a confident
    # wrong answer into the row.
    def available_models
      provider.list_models.map do |info|
        known = recognized?(info.id)

        Discovered.new(
          name: info.id,
          context_window: (info.context_window if known),
          supports_tools: (info.capabilities.include?(FUNCTION_CALLING) if known)
        )
      end
    end

    private

    # RubyLLM's marker for "I have no pattern for this id" — every recognised
    # family returns its own name. Reaching into the capability module is a
    # coupling, but the alternative is inferring recognition from the fallback
    # values themselves, which breaks silently the day they change.
    def recognized?(model_id)
      RubyLLM::Providers::OpenAI::Capabilities.model_family(model_id) != UNKNOWN_FAMILY
    end

    def provider
      RubyLLM::Provider.resolve(ruby_llm_provider).new(llm_context.config)
    end

    def normalize_base_url
      self.base_url = base_url.strip.sub(%r{/+\z}, "") if base_url.present?
    end
  end
end
