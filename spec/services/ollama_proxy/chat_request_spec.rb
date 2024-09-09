RSpec.describe OllamaProxy::ChatRequest do
  subject { described_class.new(controller_request) }

  let(:controller_request) { double('controller request', raw_post:, request_method:, path:) }
  let(:raw_post) do
    {
      model: "llama3",
      messages: [
        { role: "user", content: "why is the sky blue?" },
        { role: "assistant", content: "due to rayleigh scattering." },
        { role: "user", content: "" },
      ],
    }.to_json
  end
  let(:request_method) { "POST" }
  let(:path) { "/api/chat" }

  describe "#model" do
    it "returns the model name from the request body" do
      expect(subject.model).to eq("llama3")
    end
  end

  describe "#messages" do
    it "returns the messages from the request body" do
      expect(subject.messages).to eq([
        { "role" => "user", "content" => "why is the sky blue?" },
        { "role" => "assistant", "content" => "due to rayleigh scattering." },
        { "role" => "user", "content" => "" },
      ])
    end
  end

  describe "#messages_with_content" do
    it "returns only messages with content" do
      expect(subject.messages_with_content).to eq([
        { "role" => "user", "content" => "why is the sky blue?" },
        { "role" => "assistant", "content" => "due to rayleigh scattering." },
      ])
    end
  end

  describe "#last_user_message" do
    it "returns the last message with content from the user" do
      expect(subject.last_user_message).to eq({ "role" => "user", "content" => "why is the sky blue?" })
    end
  end

  describe "#update_last_user_message" do
    let(:new_message) { "how is that different from diffraction?" }

    it "updates the last user message with the new message content" do
      expect { subject.update_last_user_message(new_message) }
        .to change(subject, :last_user_message)
        .from({ "role" => "user", "content" => "why is the sky blue?" })
        .to({ "role" => "user", "content" => "how is that different from diffraction?" })
    end

    it "reflects the change in #body" do
      expect(subject.body).not_to match(/diffraction/)
      subject.update_last_user_message(new_message)
      expect(subject.body).to match(/diffraction/)
    end
  end
end
