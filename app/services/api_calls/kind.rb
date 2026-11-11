module ApiCalls
  # Which outbound calls are worth recording, decided from the request path.
  #
  # An allowlist, because ApiCalls::Recorder is installed in Http.connection as
  # well as RubyLLM's stack: every client in the app passes through it, and a
  # new one should record nothing until someone decides it should.
  #
  # Two kinds are absent on purpose. Embeddings would be one row per chunk batch
  # for every ingest, with bodies that are walls of floats. Docling's request
  # body *is* the uploaded file, so recording it would copy every document into
  # this table.
  module Kind
    PATTERNS = {
      "chat" => %r{/(?:chat/completions|responses)\z},
      # Ollama answers discovery on its own API rather than the OpenAI-compatible
      # one — see InferenceServers::Ollama for why.
      "discovery" => %r{/(?:models|api/tags|api/show)\z}
    }.freeze

    def self.for(url)
      PATTERNS.find { |_kind, pattern| url.path.to_s.match?(pattern) }&.first
    end
  end
end
