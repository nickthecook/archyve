require "rails_helper"

RSpec.describe Chat::Responder do
  describe ".call" do
    subject(:respond) { described_class.call(user_message, answer) }

    let(:conversation) { create(:conversation, inference_model: chat_model) }
    let(:chat_model) { create(:inference_model, kind: "chat", supports_tools: true) }

    let(:user_message) do
      create(:message, conversation:, position: 1).tap do |message|
        create(:segment, message:, content: "How do I reset the lock?")
      end
    end

    # Opened by Chat::Ask in the request, not by the responder — stamped with
    # the model the conversation was asked with, the same way Ask stamps it.
    let(:answer) do
      create(
        :message, conversation:, role: "assistant", position: 2,
        inference_model: conversation.inference_model
      )
    end

    # The responder writes through its own copy of the row, so assertions read a
    # fresh one rather than the object handed in.
    let(:turn) { answer.reload }

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

    # What a reasoning provider puts on the other channel. nil is the ordinary
    # case: a model that doesn't reason never sets it.
    let(:thinking) { nil }

    before do
      allow(llm).to receive(:complete) { |&block| block&.call(double(content: reply, thinking: thinking)) }
      allow_any_instance_of(InferenceServer).to receive(:llm_context).and_return(double(chat: llm))
    end

    # The analysis channel is not the answer: it belongs in its own segment, so
    # the transcript can collapse it and history can leave it out.
    context "when the model reasons on its way to answering" do
      let(:thinking) { double(text: "They mean the door lock. Check the manual.") }

      it "keeps the reasoning out of the prose" do
        respond
        expect(turn.segments.select(&:text?).map(&:content)).to eq(["Press [Registration]."])
      end

      it "records the reasoning as its own segment" do
        respond
        expect(turn.segments.select(&:thinking?).map(&:content))
          .to eq(["They mean the door lock. Check the manual."])
      end

      it "does not replay it back to the model" do
        respond
        expect(turn.history_content).not_to include("They mean the door lock")
      end
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
      it "attaches every tool under the name the model is told" do
        respond
        expect(llm.tools.keys).to eq(%i[search_archive read_document list_collections list_documents])
      end
    end

    # Nothing to search, so nothing to search with. A tool that could only ever
    # answer "found nothing" would have the model reporting an empty archive.
    context "when the chat draws on no collections" do
      let(:conversation) { create(:conversation, :no_collections, inference_model: chat_model) }

      it "attaches no retrieval tool" do
        respond
        expect(llm.tools).to be_empty
      end

      it "still answers" do
        respond
        expect(turn.segments.map(&:content)).to eq(["Press [Registration]."])
      end

      it "tells the model it has no archive to draw on" do
        respond
        system_prompt = llm.messages.select { it.role == :system }.map { it.content.to_s }.join
        expect(system_prompt).to include("not drawing on the archive")
      end
    end

    context "when an admin has set an instance purpose" do
      before { Setting["chat.instance_purpose"] = "Answer questions for my family from our home archive." }

      it "appends it to the system prompt" do
        respond
        system_prompt = llm.messages.select { it.role == :system }.map { it.content.to_s }.join
        expect(system_prompt).to include("Answer questions for my family from our home archive.")
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

      # Otherwise Settings goes on showing a green dot for a host every turn is
      # failing against, until an admin happens to click Check. Starts green on
      # purpose — a never-checked server is already not reachable, so asserting
      # from that state would pass without the mark.
      it "marks the server unreachable" do
        chat_model.inference_server.mark_reachable!
        respond
        expect(chat_model.inference_server.reload).not_to be_reachable
      end
    end

    context "when the chat server rejects the credentials" do
      before { allow(llm).to receive(:complete).and_raise(RubyLLM::UnauthorizedError, "bad key") }

      # The host answered — it said no. That's a Settings mistake, not an outage,
      # and a red dot would send someone to look at the wrong thing.
      it "leaves the server reachable" do
        chat_model.inference_server.mark_reachable!
        respond
        expect(chat_model.inference_server.reload).to be_reachable
      end
    end

    context "when Archyve itself has a bug" do
      before { allow(llm).to receive(:complete).and_raise(NoMethodError, "undefined method") }

      it "doesn't blame the server" do
        chat_model.inference_server.mark_reachable!
        respond
        expect(chat_model.inference_server.reload).to be_reachable
      end
    end

    context "when the turn succeeds" do
      it "marks the server reachable" do
        respond
        expect(chat_model.inference_server.reload).to be_reachable
      end

      it "clears a previous failure" do
        chat_model.inference_server.mark_unreachable!(Faraday::ConnectionFailed.new("down"))
        respond
        expect(chat_model.inference_server.reload.last_check_error).to be_nil
      end
    end
  end
end
