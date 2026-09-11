require "rails_helper"

RSpec.describe InferenceServer do
  describe "validations" do
    it "requires a name" do
      expect(build(:ollama_server, name: nil)).not_to be_valid
    end

    it "refuses a duplicate name" do
      create(:ollama_server, name: "tensor")
      expect(build(:ollama_server, name: "tensor")).not_to be_valid
    end
  end

  describe InferenceServers::Ollama do
    describe "the address" do
      context "when it carries the /v1 suffix RubyLLM wants" do
        subject(:server) { create(:ollama_server, base_url: "http://tensor:11434/v1") }

        # Stored as the root because the native API lives there and RubyLLM's
        # lives under /v1 — only the root can produce both.
        it "stores the root it implies" do
          expect(server.base_url).to eq("http://tensor:11434")
        end
      end

      context "when it has a trailing slash" do
        subject(:server) { create(:ollama_server, base_url: "http://tensor:11434/") }

        it "drops it" do
          expect(server.base_url).to eq("http://tensor:11434")
        end
      end

      context "when it is missing" do
        it "is invalid" do
          expect(build(:ollama_server, base_url: nil)).not_to be_valid
        end
      end

      context "when it isn't an http address" do
        it "is invalid" do
          expect(build(:ollama_server, base_url: "tensor:11434")).not_to be_valid
        end
      end
    end

    describe "#llm_context" do
      subject(:config) { create(:ollama_server, base_url: "http://tensor:11434").llm_context.config }

      # The point of the per-call context: RubyLLM's provider settings are
      # global and single-slot, so two Ollama hosts could never coexist through
      # RubyLLM.configure.
      it "puts the /v1 endpoint on the ollama key" do
        expect(config.ollama_api_base).to eq("http://tensor:11434/v1")
      end

      it "leaves the process-wide config alone" do
        config
        expect(RubyLLM.config.ollama_api_base).to be_nil
      end
    end

    describe "#available_models" do
      subject(:discovered) { server.available_models }

      let(:server) { create(:ollama_server, base_url: "http://tensor:11434") }
      let(:stubs) { Faraday::Adapter::Test::Stubs.new }
      # Declared as a let so a context can fail this one call. Faraday's test
      # stubs match first-registered-wins, so re-registering the path in a
      # nested before would never take effect.
      let(:gemma_show) { [200, {}, file_fixture("ollama_show_gemma4_latest.json").read] }

      before do
        allow(Http).to receive(:connection).and_return(Faraday.new { |f| f.adapter(:test, stubs) })
        stubs.get("/api/tags") { [200, {}, file_fixture("ollama_tags.json").read] }
        stubs.post("/api/show", { model: "nomic-embed-text:v1.5" }.to_json) do
          [200, {}, file_fixture("ollama_show_nomic-embed-text_v1.5.json").read]
        end
        stubs.post("/api/show", { model: "gemma4:latest" }.to_json) { gemma_show }
      end

      it "reports every model the host has pulled" do
        expect(discovered.map(&:name)).to contain_exactly("nomic-embed-text:v1.5", "gemma4:latest")
      end

      # This is the whole reason discovery bypasses RubyLLM: its Ollama provider
      # talks to /v1/models, which reports nothing but ids, and fills the gap by
      # hardcoding the same capability list onto every model.
      it "classifies an embedder from its declared capabilities" do
        expect(discovered.find { |m| m.name.start_with?("nomic") }.kind).to eq(:embedding)
      end

      it "classifies a chat model from its declared capabilities" do
        expect(discovered.find { |m| m.name.start_with?("gemma") }.kind).to eq(:chat)
      end

      it "reads the embedder's dimensions" do
        expect(discovered.find { |m| m.name.start_with?("nomic") }.dimensions).to eq(768)
      end

      # Chat models report embedding_length too — their hidden size, which has
      # nothing to do with a vector anyone would store.
      it "reports no dimensions for a chat model" do
        expect(discovered.find { |m| m.name.start_with?("gemma") }.dimensions).to be_nil
      end

      it "reads the context window" do
        expect(discovered.find { |m| m.name.start_with?("gemma") }.context_window).to eq(131_072)
      end

      it "notices tool support" do
        expect(discovered.find { |m| m.name.start_with?("gemma") }.supports_tools).to be(true)
      end

      context "when /api/show fails for one model" do
        let(:gemma_show) { [500, {}, "boom"] }

        # Dropping it would make a model invisible because a detail call timed
        # out, which is a worse answer than "you tell me".
        it "still reports the model" do
          expect(discovered.map(&:name)).to include("gemma4:latest")
        end

        it "leaves its kind for a person to decide" do
          expect(discovered.find { |m| m.name.start_with?("gemma") }.kind).to be_nil
        end
      end
    end

    describe "#check!" do
      subject(:server) { create(:ollama_server) }

      context "when the server answers" do
        before { allow(server).to receive(:available_models).and_return([]) }

        it "records that it is reachable" do
          server.check!
          expect(server.reload).to be_reachable
        end
      end

      context "when the server is unreachable" do
        before { allow(server).to receive(:available_models).and_raise(Faraday::ConnectionFailed, "refused") }

        # Reporting a bad address is the entire job, so it must not raise.
        it "returns false rather than raising" do
          expect(server.check!).to be(false)
        end

        it "records why" do
          server.check!
          expect(server.reload.last_check_error).to include("refused")
        end
      end
    end
  end

  describe InferenceServers::OpenAI do
    it "requires an API key" do
      expect(build(:openai_server, api_key: nil)).not_to be_valid
    end

    it "does not require an address" do
      expect(build(:openai_server, base_url: nil)).to be_valid
    end

    describe "#llm_context" do
      subject(:config) { create(:openai_server, api_key: "sk-live", base_url: nil).llm_context.config }

      it "puts the key on the openai key" do
        expect(config.openai_api_key).to eq("sk-live")
      end

      # Blank means OpenAI proper; RubyLLM supplies its own default.
      it "leaves the base url unset" do
        expect(config.openai_api_base).to be_nil
      end
    end
  end

  describe "the provider contract" do
    # Not NotImplementedError: that descends from ScriptError, so it would sail
    # straight through the rescue in #check! and the check would blow up instead
    # of reporting.
    it "raises a StandardError subclass when a subclass hasn't implemented it" do
      expect(described_class::MissingImplementationError.ancestors).to include(StandardError)
    end

    it "raises when the base class is asked to discover" do
      expect { described_class.new.available_models }
        .to raise_error(described_class::MissingImplementationError)
    end
  end
end
