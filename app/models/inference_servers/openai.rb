module InferenceServers
  # use RubyLLM and not Ollama directly via HTTP, since OpenAI doesn't return all the info we need and RubyLLM fills
  # in some blanks
  class OpenAI < InferenceServer
    # Matched against the id rather than taken from RubyLLM's registry, which
    # files speech, transcription and moderation models as chat.
    UNUSABLE_MODELS = {
      /image|dall-e/ => "an image model",
      /tts/ => "a speech-synthesis model",
      /whisper|transcribe/ => "a transcription model",
      /realtime/ => "a realtime-session model",
      /moderation/ => "a moderation model",
      /\A(?:babbage|davinci)-/ => "a legacy completion model"
    }.freeze
    EMBEDDING_MODEL = /embed/

    # A dated snapshot ("gpt-6-luna-2026-09-22") the registry may only know
    # undated.
    SNAPSHOT_DATE = /-\d{4}-\d{2}-\d{2}\z/

    # which server implementation is behind the OpenAI API; we try to detect these
    FLAVOURS = { "openai" => "OpenAI", "vllm" => "vLLM" }.freeze

    # vLLM puts this string in `owned_by`; more may be added here
    VLLM_OWNER = "vllm".freeze

    EMBEDDING_SKIP =
      "Dimensions aren't discoverable from this API — add it by hand if it's #{Embedding::COLUMNS_BY_DIMENSION.keys.sort.join(' or ')}-dimension.".freeze

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

    # => Array<Discovered>. Kind and tool support come from RubyLLM's registry,
    # so an id it doesn't know is reported with both nil and the import screen
    # asks. That is where every model released after the gem lands.
    def available_models
      listed = provider.list_models
      @detected_flavour = detect_flavour(listed)
      listed.map { |info| describe(info.id, served_context_window: info.metadata[:served_context_window]) }
    end

    private

    # Nil for anything that isn't recognisably vLLM, rather than a guess at
    # "openai": not-vLLM is all this knows, and the form says so.
    def detect_flavour(listed)
      VLLM_OWNER if listed.any? { it.metadata[:owned_by] == VLLM_OWNER }
    end

    def learned_from_discovery = { detected_flavour: @detected_flavour }

    # A served length is a fact about this host, where the registry's is a fact
    # about the weights; it is also the denominator the chat page measures
    # context against.
    def describe(id, served_context_window: nil)
      return Discovered.new(name: id, kind: :embedding, skip_reason: EMBEDDING_SKIP) if id.match?(EMBEDDING_MODEL)

      if (reason = unusable_reason(id))
        return Discovered.new(name: id, skip_reason: "Archyve has no use for #{reason}.")
      end

      model = registered(id)
      return Discovered.new(name: id, context_window: served_context_window) if model.nil?

      Discovered.new(
        name: id,
        kind: :chat,
        context_window: served_context_window || model.context_window,
        supports_tools: model.supports?(:function_calling)
      )
    end

    def registered(id)
      [id, id.sub(SNAPSHOT_DATE, "")].uniq.each do |candidate|
        return RubyLLM.models.find(candidate, provider: :openai)
      rescue RubyLLM::ModelNotFoundError
        next
      end

      nil
    end

    def unusable_reason(id)
      UNUSABLE_MODELS.find { |pattern, _| id.match?(pattern) }&.last
    end

    def provider
      RubyLLM::Provider.resolve(ruby_llm_provider).new(llm_context.config)
    end

    def normalize_base_url
      self.base_url = base_url.strip.sub(%r{/+\z}, "") if base_url.present?
    end
  end
end
