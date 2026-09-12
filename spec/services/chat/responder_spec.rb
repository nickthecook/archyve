require "rails_helper"

RSpec.describe Chat::Responder do
  describe ".call" do
    subject(:respond) { described_class.call(user_message) }

    let(:conversation) { create(:conversation, inference_model: chat_model) }
    let(:chat_model) { create(:inference_model, kind: "chat", supports_tools: true) }
    let(:turn) { conversation.messages.reload.last }

    let(:user_message) do
      create(:message, conversation:, position: 1).tap do |message|
        create(:segment, message:, content: "How do I reset the lock?")
      end
    end

    before { allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to).and_call_original }

    # A **real** RubyLLM::Chat with only the network stubbed, so
    # with_instructions and with_tool run for real. A doubled chat accepts
    # anything, which is how `with_tool(tool, calls: 2)` — an option RubyLLM
    # rejects at runtime — reached a live model before any spec noticed.
    let(:llm) do
      RubyLLM.context { |config| config.ollama_api_base = "http://test/v1" }
        .chat(model: "test-model", provider: :ollama, assume_model_exists: true)
    end

    let(:reply) { "Press [Registration]." }

    before do
      allow(llm).to receive(:complete) { |&block| block&.call(double(content: reply)) }
      allow_any_instance_of(InferenceServer).to receive(:llm_context).and_return(double(chat: llm))
    end

    context "when the model answers" do
      it "records what it said" do
        respond
        expect(turn.segments.map(&:content)).to eq(["Press [Registration]."])
      end

      it "does not record an error" do
        respond
        expect(turn.error).to be_nil
      end

      # RubyLLM's `calls:` counts tool calls within one response, not rounds
      # within a turn, and raises on an integer. The round budget is the tool's.
      # This passes only because with_tool is the gem's own, not a stub.
      it "attaches the retrieval tool under the name the model is told" do
        respond
        expect(llm.tools.keys).to eq([:search_archive])
      end
    end

    context "when no chat model is configured" do
      let(:conversation) { create(:conversation, inference_model: nil) }

      it "records why rather than raising" do
        expect { respond }.not_to raise_error
      end

      it "says what's missing" do
        respond
        expect(turn.error).to include("No chat model is configured")
      end
    end

    # No prompt-stuffing fallback: deciding whether to search, and what to
    # search for, is the part a tool-less model cannot do.
    context "when the chosen model can't call tools" do
      let(:chat_model) { create(:inference_model, kind: "chat", supports_tools: false) }

      it "declines rather than degrading" do
        respond
        expect(turn.error).to include("can't call tools")
      end

      it "asks nothing of the model" do
        respond
        expect(llm.messages).to be_empty
      end
    end

    context "when the chat server can't be reached" do
      before { allow(llm).to receive(:complete).and_raise(Faraday::ConnectionFailed, "down") }

      it "records the failure on the turn rather than raising at the user" do
        expect { respond }.not_to raise_error
      end

      it "names the server to check" do
        respond
        expect(turn.error).to include(chat_model.inference_server.name)
      end
    end
  end
end
