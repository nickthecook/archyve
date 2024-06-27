RSpec.describe LlmClients::Ollama::Client do
  subject do
    described_class.new(
      endpoint:,
      api_key:,
      model: nil,
      embedding_model: nil,
      temperature:,
      batch_size:
    )
  end

  let(:endpoint) { "http://localhost:11434/v1/completion" }
  let(:api_key) { "test-api-key" }
  let(:model) { "codestral:latest" }
  let(:embedding_model) { "nomic-embed-text" }
  let(:temperature) { 0.1 }
  let(:batch_size) { 10 }
end
