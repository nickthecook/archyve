require 'factory_bot'

RSpec.describe LlmClients::Ollama::Chat do
  subject { described_class.new(conversation) }

  let(:conversation) { build(:conversation) }

  it "returns a prompt with the user message" do
    expect(subject.prompt).to eq(
      {
        model: "mixalot:latest",
        messages: [
          {
            role: "user",
            content: "Write a simple ruby program.",
          },
          {
            role: "assistant",
            content: "loop { puts 'HA' }",
          },
          {
            role: "user",
            content: "Not exactly what I meant.",
          },
        ],
      }
    )
  end
end
