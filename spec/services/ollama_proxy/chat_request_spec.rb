RSpec.describe OllamaProxy::ChatRequest do
  subject { described_class.new(controller_request) }

  let(:controller_request) { instance_double(ActionDispatch::Request, raw_post:, request_method:, path:) }
  let(:request_method) { "POST" }
  let(:path) { "/api/chat" }

  shared_context "when messages are in Ollama format" do
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
  end

  shared_context "when messages are in OpenAI format" do
    let(:raw_post) do
      {
        model: "llama3",
        messages: [
          { role: "user", content: [{ type: "text", text: "why is the sky blue?" }] },
          { role: "assistant", content: [{ type: "text", text: "due to rayleigh scattering." }] },
          { role: "user", content: [{ type: "text", text: "" }] },
        ],
      }.to_json
    end
  end

  # this came from HF chat-ui in the wild, was causing a problem
  shared_context "when empty system message is included" do
    let(:raw_post) do
      {
        model: "llama3.1:latest",
        stream: true,
        messages: [
          { role: "system", content: "" },
          { role: "user", content: "why is the sky blue?" },
        ],
      }.to_json
    end
  end

  include_context "when messages are in Ollama format"

  describe "#model" do
    it "returns the model name from the request body" do
      expect(subject.model).to eq("llama3")
    end
  end

  describe "#messages" do
    it "returns the messages from the request body" do
      expect(subject.messages.map(&:content)).to eq([
        "why is the sky blue?",
        "due to rayleigh scattering.",
        "",
      ])
      expect(subject.messages.map(&:role)).to eq(%w[user assistant user])
    end

    context "when when messages are in OpenAI format" do
      include_context "when messages are in OpenAI format"

      it "returns the messages from the request body" do
        expect(subject.messages.map(&:content)).to eq([
          "why is the sky blue?",
          "due to rayleigh scattering.",
          "",
        ])
        expect(subject.messages.map(&:role)).to eq(%w[user assistant user])
      end
    end

    context "when empty system message is included" do
      include_context "when empty system message is included"

      it "returns the messages from the request body" do
        expect(subject.messages.map(&:content)).to eq([
          "",
          "why is the sky blue?",
        ])
        expect(subject.messages.map(&:role)).to eq(%w[system user])
      end
    end
  end

  describe "#messages_with_content" do
    it "returns only messages with content" do
      expect(subject.messages_with_content.map(&:content)).to eq([
        "why is the sky blue?",
        "due to rayleigh scattering.",
      ])
    end

    context "when when messages are in OpenAI format" do
      include_context "when messages are in OpenAI format"

      it "returns only messages with content" do
        expect(subject.messages_with_content.map(&:content)).to eq([
          "why is the sky blue?",
          "due to rayleigh scattering.",
        ])
      end
    end
  end

  describe "#last_user_message" do
    it "returns the last message from the user" do
      expect(subject.last_user_message.content).to eq("")
      expect(subject.last_user_message.role).to eq("user")
    end

    context "when when messages are in OpenAI format" do
      include_context "when messages are in OpenAI format"

      it "returns the last message from the user" do
        expect(subject.last_user_message.content).to eq("")
        expect(subject.last_user_message.role).to eq("user")
      end
    end
  end

  describe "#update_last_user_message" do
    let(:new_message) { "how is that different from diffraction?" }

    it "updates the last user message with the new message content" do
      expect { subject.update_last_user_message(new_message) }
        .to change(subject.last_user_message, :content)
        .from("")
        .to("how is that different from diffraction?")
    end

    it "reflects the change in #body" do
      expect(subject.body).not_to match(/diffraction/)
      subject.update_last_user_message(new_message)
      expect(subject.body).to eq({
        "model" => "llama3",
        "messages" => [
          { "role" => "user", "content" => "why is the sky blue?" },
          { "role" => "assistant", "content" => "due to rayleigh scattering." },
          { "role" => "user", "content" => "how is that different from diffraction?" },
        ],
      }.to_json)
    end

    context "when when messages are in OpenAI format" do
      include_context "when messages are in OpenAI format"

      it "updates the last user message with the new message content" do
        expect { subject.update_last_user_message(new_message) }
          .to change(subject.last_user_message, :content)
          .from("")
          .to("how is that different from diffraction?")
      end

      it "reflects the change in #body" do
        expect(subject.body).not_to match(/diffraction/)
        subject.update_last_user_message(new_message)
        expect(subject.body).to eq({
          "model" => "llama3",
          "messages" => [
            { "role" => "user", "content" => [{ "type" => "text", "text" => "why is the sky blue?" }] },
            { "role" => "assistant", "content" => [{ "type" => "text", "text" => "due to rayleigh scattering." }] },
            { "role" => "user", "content" => [{ "type" => "text", "text" => "how is that different from diffraction?" }] },
          ],
        }.to_json)
      end
    end
  end
end
