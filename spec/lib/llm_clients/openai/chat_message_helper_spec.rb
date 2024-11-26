require 'factory_bot'

RSpec.describe LlmClients::Openai::ChatMessageHelper do
  subject { described_class.new(conversation.messages.last) }

  let(:conversation) { create(:conversation) }

  it "returns a chat request body with all messages included" do
    expect(subject.chat_history).to eq(
      [
        {
          role: "system",
          content: "You are Archyve, an AI assistant.",
        },
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
      ]
    )
  end

  context "when conversation is augmented" do
    let(:conversation) { create(:augmented_conversation) }

    it "returns a chat request body that uses the augmented prompt from only the last message" do
      expect(subject.chat_history).to eq(
        [
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
            content: <<~PROMPT,
              Home directories are located a /home/username or /Users/username in a sane system.
              Write a ruby program that lists the contents of the home directory for user 'bob'.
            PROMPT
          },
        ]
      )
    end
  end
end
