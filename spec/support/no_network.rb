# Fails any example that opens a real TCP connection.
#
# Every outbound call in this app goes somewhere a spec must not depend on: a
# Docling sidecar, an Ollama host on somebody's LAN, api.openai.com with a real
# key and a real bill. Those are stubbed at seams the specs choose deliberately
# — Http.connection, RubyLLM::Provider, Embeddings::Embed — and this is what
# notices when a new spec forgets, or when a refactor moves the seam and the
# stub silently stops covering anything.
#
# The database is unaffected: the pg gem connects through libpq, in C, so it
# never passes through these Ruby entry points. That is what makes an
# everything-blocked default practical here rather than needing an allow list.
module NoNetwork
  class ConnectionAttempted < StandardError
    def initialize(host, port)
      super(<<~MESSAGE)
        Tried to open a real connection to #{host}:#{port}.

        Specs must not reach the network. Stub the seam instead:
          Ollama discovery  -> Http.connection (Faraday's :test adapter)
          OpenAI discovery  -> RubyLLM::Provider.resolve
          inference         -> InferenceServer#llm_context
          embedding         -> Embeddings::Embed.document / .query
          extraction        -> Docling::Client
      MESSAGE
    end
  end
end

class TCPSocket
  class << self
    def open(host, port, *) = raise(NoNetwork::ConnectionAttempted.new(host, port))
    alias_method :new, :open
  end
end

class Socket
  class << self
    def tcp(host, port, *, **) = raise(NoNetwork::ConnectionAttempted.new(host, port))
  end
end
