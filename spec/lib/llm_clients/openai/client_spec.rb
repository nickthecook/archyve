RSpec.describe LlmClients::Openai::Client do
  subject { described_class.new(prompt, traceable:) }

  let(:prompt) { 'Hello, world' }
  let(:traceable) { nil }

  describe "#complete" do
  end
end
