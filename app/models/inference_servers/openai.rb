module InferenceServers
  # use RubyLLM and not Ollama directly via HTTP, since OpenAI doesn't return all the info we need and RubyLLM fills
  # in some blanks
  class OpenAI < InferenceServer
    # the RubyLLM name for tool calling capability
    FUNCTION_CALLING = "function_calling".freeze
    # the RubyLLM family string when it doesn't know what family a model is
    UNKNOWN_FAMILY = "other".freeze

    # these "families" aren't usable, since they don't handle text
    UNUSABLE_FAMILIES = {
      /image/ => "an image model",
      /tts/ => "a speech-synthesis model",
      /whisper|transcribe/ => "a transcription model",
      /realtime/ => "a realtime-session model",
      /\Amoderation\z/ => "a moderation model",
      /\A(?:babbage|davinci)\z/ => "a legacy completion model"
    }.freeze

    # which server implementation is behind the OpenAI API; we try to detect these
    FLAVOURS = { "openai" => "OpenAI", "vllm" => "vLLM" }.freeze

    # vLLM puts this string in `owned_by`; more may be added here
    VLLM_OWNER = "vllm".freeze

    EMBEDDING_SKIP =
      "Dimensions aren't discoverable from this API — add it by hand if it's #{Embedding::DIMENSIONS}-dimension.".freeze

    before_validation :normalize_base_url

    validates :api_key, presence: true
    validates :flavour, inclusion: { in: FLAVOURS.keys }, allow_blank: true

    # `flavour` is where we store a user-override; `detected_flavour` is what we detected
    store_accessor :config, :flavour, :detected_flavour

    def self.type_label = "OpenAI"

    def self.description
      "OpenAI, or any endpoint that speaks its API — vLLM, LiteLLM, a gateway."
    end

    # An address is optional here, unlike Ollama: blank means OpenAI proper.
    def self.requires_base_url? = false
    def self.requires_api_key? = true
    def self.flavours = FLAVOURS
    def self.base_url_placeholder = "https://api.openai.com/v1"
    def self.base_url_hint = "Leave blank for OpenAI itself. Set it to reach anything else that speaks the same API."

    def flavour_in_effect = flavour.presence || detected_flavour
    def vllm? = flavour_in_effect == VLLM_OWNER

    # vLLM batches several tokens into one streamed event, so asking it to name
    # the tokens in each is the only way to know a rate. See Chat::Pace.
    def stream_params = vllm? ? { return_token_ids: true } : {}

    def ruby_llm_provider = :openai

    def apply_config(config)
      config.openai_api_key = api_key
      config.openai_api_base = base_url if base_url.present?
    end

    # => Array<Discovered>. No kind — see the class comment.
    #
    # Tool support is worth taking from RubyLLM, but only where it actually
    # recognises the model: for anything else its capability module falls back to
    # defaults — 4,096 tokens and no function calling — and those are
    # pattern-matching guesses, not something the endpoint said. Reported as nil
    # so the import screen asks instead of writing a confident wrong answer into
    # the row.
    #
    # The context window is the exception, because vLLM does say — see
    # #context_window_for.
    def available_models
      listed = provider.list_models
      @detected_flavour = detect_flavour(listed)
      listed.map { |info| describe(info) }
    end

    private

    # Nil for anything that isn't recognisably vLLM, rather than a guess at
    # "openai": not-vLLM is all this knows, and the form says so.
    def detect_flavour(listed)
      VLLM_OWNER if listed.any? { it.metadata[:owned_by] == VLLM_OWNER }
    end

    def learned_from_discovery = { detected_flavour: @detected_flavour }

    # Classification comes from RubyLLM's family patterns, which are a guess at
    # the id rather than anything the endpoint said — so an id it has no pattern
    # for yields `kind: nil` and the import screen asks, rather than a confident
    # default. That fallback is load-bearing: it is what a model released after
    # the gem lands in.
    def describe(info)
      family = family_for(info.id)

      # An id the registry has no pattern for is the case a served length exists
      # for, so this branch keeps it: the *kind* is genuinely unknowable here and
      # the import screen asks, but a served context length is the endpoint's own
      # answer rather than a guess at the id, and there is no reason to discard
      # it along with the rest.
      if family == UNKNOWN_FAMILY
        return Discovered.new(name: info.id, context_window: info.metadata[:served_context_window])
      end

      return Discovered.new(name: info.id, kind: :embedding, skip_reason: EMBEDDING_SKIP) if embedding?(family)

      if (reason = unusable_reason(family))
        return Discovered.new(name: info.id, skip_reason: "Archyve has no use for #{reason}.")
      end

      Discovered.new(
        name: info.id,
        kind: :chat,
        context_window: context_window_for(info),
        supports_tools: info.capabilities.include?(FUNCTION_CALLING)
      )
    end

    # What the endpoint said, where it said anything — see
    # config/initializers/ruby_llm_served_context_window.rb. Preferred over the
    # registry's figure because a served length is a fact about this host, and
    # the registry's is a guess at the id; it is also the one the chat page
    # measures context against, so a wrong denominator shows up there as a bar
    # that never fills or one that is always full.
    def context_window_for(info)
      info.metadata[:served_context_window] || info.context_window
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
