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

    describe "#available_models" do
      subject(:discovered) { create(:openai_server).available_models }

      let(:listed) do
        [
          model_info("gpt-4o", context_window: 128_000, capabilities: %w[function_calling vision]),
          model_info("gpt-5.6-luna", context_window: 128_000, capabilities: %w[function_calling reasoning]),
          model_info("some-unreleased-model", context_window: 4_096, capabilities: [])
        ]
      end

      def model_info(id, context_window:, capabilities:)
        instance_double(RubyLLM::Model::Info, id:, context_window:, capabilities:)
      end

      before do
        allow(RubyLLM::Provider).to receive(:resolve).with(:openai)
          .and_return(class_double(RubyLLM::Providers::OpenAI, new: instance_double(
            RubyLLM::Providers::OpenAI, list_models: listed
          )))
      end

      it "reports every model the endpoint lists" do
        expect(discovered.map(&:name)).to include("gpt-4o", "some-unreleased-model")
      end

      # The bug this spec exists for: capabilities were being dropped, so every
      # OpenAI model imported claiming it couldn't call tools.
      it "reads tool support from the capabilities" do
        expect(discovered.find { |m| m.name == "gpt-4o" }.supports_tools).to be(true)
      end

      it "reads the context window" do
        expect(discovered.find { |m| m.name == "gpt-4o" }.context_window).to eq(128_000)
      end

      # An OpenAI-compatible /v1/models reports neither figure, so RubyLLM
      # pattern-matches the id. For an id it has no pattern for it falls back to
      # 4,096 tokens and no function calling — guesses, which must not be stored
      # as though the endpoint had said them.
      context "with a model RubyLLM doesn't recognise" do
        subject(:model) { discovered.find { |m| m.name == "some-unreleased-model" } }

        it "reports tool support as unknown rather than false" do
          expect(model.supports_tools).to be_nil
        end

        it "reports no context window rather than the 4,096 fallback" do
          expect(model.context_window).to be_nil
        end
      end

      context "classifying the real OpenAI catalogue" do
        subject(:model) { described_class.new.send(:describe, model_info(id, context_window: 128_000, capabilities: [])) }

        # /v1/models says nothing about purpose, so this comes from RubyLLM's
        # family patterns — a guess at the id, which is why an unmatched id
        # falls through to "ask" rather than to a default.
        {
          "gpt-4o" => :chat,
          "gpt-4o-search-preview" => :chat,
          "text-embedding-3-small" => :embedding
        }.each do |id, kind|
          context "with #{id}" do
            let(:id) { id }

            it "classifies it as #{kind}" do
              expect(model.kind).to eq(kind)
            end
          end
        end

        # The distinction that is easy to get backwards: a different *input* is
        # a capability of a chat model, a different *call* is not a chat model
        # at all. Getting this wrong files gpt-4o-audio somewhere the chat
        # picker can't see it.
        context "with gpt-4o-audio-preview" do
          let(:id) { "gpt-4o-audio-preview" }

          it "is still a chat model, because audio is an input not a call" do
            expect(model.kind).to eq(:chat)
          end

          it "is importable" do
            expect(model).not_to be_skipped
          end
        end

        {
          "whisper-1" => "transcription",
          "tts-1" => "speech-synthesis",
          "gpt-image-1" => "image",
          "omni-moderation-latest" => "moderation",
          "davinci-002" => "legacy completion"
        }.each do |id, description|
          context "with #{id}" do
            let(:id) { id }

            # Archyve has chat and embedding, so there is no honest kind for
            # these. Reported rather than filtered out, the way a skipped file
            # still appears in a source scan.
            it "is skipped as #{description}" do
              expect(model.skip_reason).to include(description)
            end

            it "gets no kind" do
              expect(model.kind).to be_nil
            end
          end
        end

        # Recognisable, but unusable: this API never reports dimensions and the
        # column is a fixed 768.
        context "with an OpenAI embedding model" do
          let(:id) { "text-embedding-3-large" }

          it "is skipped" do
            expect(model).to be_skipped
          end

          it "points at the manual form" do
            expect(model.skip_reason).to include("by hand")
          end
        end

        context "with an id RubyLLM has no pattern for" do
          let(:id) { "gpt-7-unreleased" }

          it "leaves kind for a person to decide" do
            expect(model.kind).to be_nil
          end

          # Not skipped — unknown is not the same as unusable, and this is
          # where every model released after the gem lands.
          it "is still importable" do
            expect(model).not_to be_skipped
          end
        end
      end
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
