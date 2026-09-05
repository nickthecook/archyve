# RubyLLM configuration. Archyve is Ollama-first: the chat provider is swappable
# later, but the embedding provider is corpus-wide (embeddings across models
# aren't comparable), so nomic-embed-text is fixed here for now.
#
# We use the modern RubyLLM API (RubyLLM.embed / RubyLLM.chat), NOT the legacy
# acts_as integration — the acts_as deprecation warning on boot is expected.
RubyLLM.configure do |config|
  # Ollama's OpenAI-compatible endpoint. Override with OLLAMA_API_BASE (must
  # include the /v1 suffix) to point at a remote Ollama host.
  config.ollama_api_base = ENV.fetch("OLLAMA_API_BASE", "http://localhost:11434/v1")

  # Corpus-wide embedding model. Keep in sync with Embedding::DEFAULT_MODEL
  # (can't reference the autoloaded model constant this early in boot).
  config.default_embedding_model = ENV.fetch("EMBEDDING_MODEL", "nomic-embed-text:v1.5")
end
