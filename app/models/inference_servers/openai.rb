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

    # Families that are a different *call*, not a different input — so Archyve
    # has no `kind` to file them under and won't offer them for import.
    #
    # The distinction matters and is easy to get backwards. `gpt-4o-audio` is a
    # **chat** model that happens to accept audio, so it is absent from this
    # table and imports as chat with audio as a capability; `whisper` and `tts`
    # are transcription and synthesis, driven by RubyLLM.transcribe and a
    # different endpoint entirely. Ollama draws the same line for us —
    # gemma4 reports `["completion", "vision", "audio", "tools", "thinking"]`,
    # where `completion` is the kind and the rest are capabilities of it.
    #
    # These entries retire themselves: the day Archyve paints or transcribes,
    # the matching line comes out and becomes a kind instead.
    UNUSABLE_FAMILIES = {
      /image/ => "an image model",
      /tts/ => "a speech-synthesis model",
      /whisper|transcribe/ => "a transcription model",
      /realtime/ => "a realtime-session model",
      /\Amoderation\z/ => "a moderation model",
      /\A(?:babbage|davinci)\z/ => "a legacy completion model"
    }.freeze

    # Embedding models are recognisable, but unusable without a dimension count
    # this API never reports — and Archyve's column is a fixed 768. Pointed at
    # the manual form, which has a dimensions field and validates it.
    EMBEDDING_SKIP =
      "Dimensions aren't discoverable from this API — add it by hand if it's #{Embedding::DIMENSIONS}-dimension.".freeze

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
      provider.list_models.map { |info| describe(info) }
    end

    private

    # Classification comes from RubyLLM's family patterns, which are a guess at
    # the id rather than anything the endpoint said — so an id it has no pattern
    # for yields `kind: nil` and the import screen asks, rather than a confident
    # default. That fallback is load-bearing: it is what a model released after
    # the gem lands in.
    def describe(info)
      family = family_for(info.id)

      return Discovered.new(name: info.id) if family == UNKNOWN_FAMILY
      return Discovered.new(name: info.id, kind: :embedding, skip_reason: EMBEDDING_SKIP) if embedding?(family)

      if (reason = unusable_reason(family))
        return Discovered.new(name: info.id, skip_reason: "Archyve has no use for #{reason}.")
      end

      Discovered.new(
        name: info.id,
        kind: :chat,
        context_window: info.context_window,
        supports_tools: info.capabilities.include?(FUNCTION_CALLING)
      )
    end

    # Reaching into RubyLLM's capability module is a coupling, but the
    # alternative is inferring recognition from its fallback values (4,096
    # tokens, no function calling), which breaks silently the day they change.
    def family_for(model_id)
      RubyLLM::Providers::OpenAI::Capabilities.model_family(model_id)
    end

    def embedding?(family) = family.start_with?("embedding")

    def unusable_reason(family)
      UNUSABLE_FAMILIES.find { |pattern, _| family.match?(pattern) }&.last
    end

    def provider
      RubyLLM::Provider.resolve(ruby_llm_provider).new(llm_context.config)
    end

    def normalize_base_url
      self.base_url = base_url.strip.sub(%r{/+\z}, "") if base_url.present?
    end
  end
end
