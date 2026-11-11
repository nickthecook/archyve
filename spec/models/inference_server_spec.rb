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

  # What a streamed delta is worth when the server sent no count of its own.
  # Ollama is the only one that flushes a token at a time; assuming it of
  # anything else reported a third of the real rate. See Chat::Pace.
  describe "#one_token_per_delta?" do
    context "with Ollama" do
      it "counts a delta as a token" do
        expect(create(:ollama_server)).to be_one_token_per_delta
      end
    end

    context "with anything speaking the OpenAI API" do
      it "assumes nothing, whatever flavour it is" do
        expect(create(:openai_server, config: { flavour: "vllm" })).not_to be_one_token_per_delta
      end
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

      # The import screen is the only other place a context window is written, so
      # a model imported before its provider could report one would stay blank
      # for as long as the row lived — and the meter above the composer has no
      # denominator without it.
      context "when discovery reports a window for a model that is already imported" do
        let!(:model) { create(:inference_model, inference_server: server, name: "qwen3-27b", context_window: nil) }

        before do
          allow(server).to receive(:available_models).and_return([
            InferenceServer::Discovered.new(name: "qwen3-27b", kind: :chat, context_window: 65_536)
          ])
        end

        it "fills it in" do
          server.check!
          expect(model.reload.context_window).to eq(65_536)
        end
      end

      # The window belongs to the server, and a host restarted with a different
      # --max-model-len is serving a different length than it was yesterday. A
      # stale figure is the denominator the chat page measures context against.
      context "when the server is now serving a different window" do
        let!(:model) { create(:inference_model, inference_server: server, name: "qwen3-27b", context_window: 8_192) }

        before do
          allow(server).to receive(:available_models).and_return([
            InferenceServer::Discovered.new(name: "qwen3-27b", kind: :chat, context_window: 65_536)
          ])
        end

        it "takes the new figure" do
          server.check!
          expect(model.reload.context_window).to eq(65_536)
        end
      end

      # Only the providers that genuinely report one say anything here. An
      # endpoint that stayed quiet must not be read as "no window".
      context "when discovery reports no window" do
        let!(:model) { create(:inference_model, inference_server: server, name: "qwen3-27b", context_window: 8_192) }

        before do
          allow(server).to receive(:available_models).and_return([
            InferenceServer::Discovered.new(name: "qwen3-27b", kind: :chat)
          ])
        end

        it "keeps what the row had" do
          server.check!
          expect(model.reload.context_window).to eq(8_192)
        end
      end

      # Importing is a person's choice. A server that has grown a model is not
      # Archyve's cue to start using it.
      context "when discovery reports a model nobody imported" do
        before do
          allow(server).to receive(:available_models).and_return([
            InferenceServer::Discovered.new(name: "brand-new", kind: :chat, context_window: 65_536)
          ])
        end

        it "creates nothing" do
          expect { server.check! }.not_to change(InferenceModel, :count)
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

    describe "#mark_reachable!" do
      subject(:server) { create(:ollama_server) }

      context "when the server has never been checked" do
        it "records that it answered" do
          server.mark_reachable!
          expect(server.reload).to be_reachable
        end
      end

      context "when it was last seen failing" do
        before { server.mark_unreachable!(Faraday::ConnectionFailed.new("refused")) }

        # The recovery edge: a change is never throttled, or a server that came
        # back would stay red until someone clicked Check.
        it "flips it back at once" do
          server.mark_reachable!
          expect(server.reload).to be_reachable
        end

        it "clears the stale error" do
          server.mark_reachable!
          expect(server.reload.last_check_error).to be_nil
        end
      end

      context "when it was already reachable a moment ago" do
        before { server.mark_reachable! }

        it "doesn't write again" do
          expect { server.mark_reachable! }.not_to(change { server.reload.last_checked_at })
        end
      end

      context "when the last success has gone stale" do
        before { server.update_columns(last_check_status: "ok", last_checked_at: 1.hour.ago) }

        it "refreshes the timestamp" do
          expect { server.mark_reachable! }.to(change { server.reload.last_checked_at })
        end
      end

      # updated_at is the configuration's mtime; traffic must not disturb it.
      it "leaves updated_at alone" do
        server.update_columns(updated_at: 1.day.ago)
        expect { server.mark_reachable! }.not_to(change { server.reload.updated_at })
      end
    end

    describe "#mark_unreachable!" do
      subject(:server) { create(:ollama_server) }

      before { server.mark_reachable! }

      it "turns the badge red" do
        server.mark_unreachable!(Faraday::ConnectionFailed.new("refused"))
        expect(server.reload).not_to be_reachable
      end

      it "records why" do
        server.mark_unreachable!(Faraday::ConnectionFailed.new("refused"))
        expect(server.reload.last_check_error).to include("refused")
      end

      it "caps a runaway message" do
        server.mark_unreachable!(Faraday::ConnectionFailed.new("x" * 5_000))
        expect(server.reload.last_check_error.length).to be <= described_class::CHECK_ERROR_LIMIT
      end

      # A row that has gone invalid for an unrelated reason still has to be able
      # to report trouble — that is the whole point of the mark.
      context "when the row would fail validation" do
        subject(:server) { create(:openai_server) }

        before { server.update_columns(api_key: nil) }

        it "still records the failure" do
          server.mark_unreachable!(Faraday::ConnectionFailed.new("refused"))
          expect(server.reload).not_to be_reachable
        end
      end
    end

    describe ".due_for_check" do
      subject(:due) { InferenceServer.due_for_check }

      context "with a server that has never been checked" do
        let!(:server) { create(:ollama_server, last_checked_at: nil) }

        it "is due" do
          expect(due).to include(server)
        end
      end

      context "with a server checked longer ago than the interval" do
        let!(:server) { create(:ollama_server, last_checked_at: 2.hours.ago) }

        it "is due" do
          expect(due).to include(server)
        end
      end

      context "with a server traffic has just proved reachable" do
        let!(:server) { create(:ollama_server).tap(&:mark_reachable!) }

        it "is not due" do
          expect(due).not_to include(server)
        end
      end

      context "with a stale server that is currently failing" do
        let!(:server) do
          create(:ollama_server).tap { it.update_columns(last_check_status: "failed", last_checked_at: 2.hours.ago) }
        end

        it "is still due, since only a probe can turn an idle host green again" do
          expect(due).to include(server)
        end
      end
    end

    describe ".unreachable_error?" do
      # "Is the host up?" — not Ingestion::Outcome's "will a retry help?", which
      # answers differently for the last two.
      {
        Faraday::ConnectionFailed => true,
        Faraday::TimeoutError => true,
        RubyLLM::ServerError => true,
        RubyLLM::ServiceUnavailableError => true,
        RubyLLM::RateLimitError => false,
        RubyLLM::UnauthorizedError => false,
        NoMethodError => false
      }.each do |error_class, expected|
        context "given #{error_class}" do
          it "is #{expected}" do
            expect(described_class.unreachable_error?(error_class.new("boom"))).to be(expected)
          end
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

      def model_info(id, context_window:, capabilities:, owned_by: "openai", served_context_window: nil)
        instance_double(
          RubyLLM::Model::Info, id:, context_window:, capabilities:,
          metadata: { owned_by:, served_context_window: }
        )
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

      # vLLM serves each model at a fixed length and says so. It is the better
      # number than anything RubyLLM's registry pattern-matched out of the id:
      # a server started with less truncates whatever the weights could manage.
      context "with a model the endpoint reports a served length for" do
        let(:listed) do
          [
            model_info("gpt-4o", context_window: 128_000, capabilities: %w[function_calling],
                                 owned_by: "vllm", served_context_window: 24_576),
            model_info("qwen3-27b", context_window: 4_096, capabilities: [],
                                    owned_by: "vllm", served_context_window: 32_768)
          ]
        end

        it "takes the endpoint's figure over the registry's" do
          expect(discovered.find { |m| m.name == "gpt-4o" }.context_window).to eq(24_576)
        end

        # The case the field exists for: an id no registry has a pattern for,
        # where the alternative is nil and a person typing it in by hand.
        it "reports it for a model RubyLLM has never heard of" do
          expect(discovered.find { |m| m.name == "qwen3-27b" }.context_window).to eq(32_768)
        end

        it "still leaves the kind for a person to decide" do
          expect(discovered.find { |m| m.name == "qwen3-27b" }.kind).to be_nil
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

    # RubyLLM's model parser keeps only `object` and `owned_by` from each entry,
    # so config/initializers/ruby_llm_served_context_window.rb puts the served
    # length back. Exercised through the real parser: the prepend is the part
    # that can quietly stop working, and nothing else would notice.
    describe "carrying a served length through RubyLLM" do
      subject(:parsed) do
        create(:openai_server).send(:provider).send(
          :parse_list_models_response, response, "openai", RubyLLM::Providers::OpenAI::Capabilities
        )
      end

      let(:response) { instance_double(Faraday::Response, body: { "data" => [entry] }) }

      context "when the endpoint is vLLM" do
        let(:entry) do
          { "id" => "qwen3-27b", "object" => "model", "owned_by" => "vllm", "max_model_len" => 32_768 }
        end

        it "keeps what the endpoint said" do
          expect(parsed.sole.metadata[:served_context_window]).to eq(32_768)
        end

        it "leaves the fields RubyLLM already carried alone" do
          expect(parsed.sole.metadata[:owned_by]).to eq("vllm")
        end
      end

      # LiteLLM reports the same thing under its own name, and `owned_by` is
      # whatever it is proxying — so the field is all there is to go on.
      context "when the endpoint is LiteLLM" do
        let(:entry) do
          {
            "id" => "qwen3.8-27b", "object" => "model", "owned_by" => "openai",
            "max_input_tokens" => 65_536, "max_output_tokens" => 65_536
          }
        end

        it "keeps what the endpoint said" do
          expect(parsed.sole.metadata[:served_context_window]).to eq(65_536)
        end
      end

      context "when the endpoint is OpenAI itself" do
        let(:entry) { { "id" => "gpt-4o", "object" => "model", "owned_by" => "system" } }

        it "reports nothing rather than a guess" do
          expect(parsed.sole.metadata[:served_context_window]).to be_nil
        end
      end
    end

    # Several very different servers speak this API, and they stream in
    # different enough ways that Archyve has to know which it is talking to —
    # see #stream_params. Detected rather than asked for.
    describe "which server it is" do
      subject(:server) { create(:openai_server) }

      let(:owned_by) { "openai" }

      before do
        listed = [
          instance_double(
            RubyLLM::Model::Info,
            id: "qwen3-27b", context_window: 24_576, capabilities: ["function_calling"],
            metadata: { owned_by: }
          )
        ]
        allow(RubyLLM::Provider).to receive(:resolve).with(:openai)
          .and_return(class_double(RubyLLM::Providers::OpenAI, new: instance_double(
            RubyLLM::Providers::OpenAI, list_models: listed
          )))
      end

      context "when the models it lists are owned by vllm" do
        let(:owned_by) { "vllm" }

        it "records what the endpoint said about itself" do
          server.check!
          expect(server.detected_flavour).to eq("vllm")
        end

        it "asks for the token counts a rate needs" do
          server.check!
          expect(server.stream_params).to eq(return_token_ids: true)
        end
      end

      context "when the endpoint claims nothing recognisable" do
        it "detects nothing rather than guessing" do
          server.check!
          expect(server.detected_flavour).to be_nil
        end

        it "sends nothing a stock OpenAI endpoint would reject" do
          server.check!
          expect(server.stream_params).to eq({})
        end
      end

      # The address now answers for something else. A detection kept from the
      # last check would go on asking it for fields it has never heard of.
      context "when a server detected as vLLM stops looking like one" do
        before { server.update!(detected_flavour: "vllm") }

        it "forgets what it saw before" do
          server.check!
          expect(server.detected_flavour).to be_nil
        end
      end

      # Detection is a guess about somebody else's infrastructure, and a proxy
      # can hide what is behind it. Then the person setting this up knows better.
      context "when a flavour has been chosen by hand" do
        before { server.update!(flavour: "vllm") }

        it "outranks what detection saw" do
          server.check!
          expect(server).to be_vllm
        end
      end

      it "rejects a flavour it has no behaviour for" do
        expect(build(:openai_server, flavour: "whatever")).not_to be_valid
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

  describe InferenceServers::Azure do
    it "requires an address" do
      expect(build(:azure_server, base_url: nil)).not_to be_valid
    end

    it "requires an https address" do
      expect(build(:azure_server, base_url: "http://archyve.openai.azure.com")).not_to be_valid
    end

    it "requires an API key" do
      expect(build(:azure_server, api_key: nil)).not_to be_valid
    end

    describe "normalizing the address" do
      subject(:base_url) { create(:azure_server, base_url: pasted).base_url }

      context "with a bare resource endpoint" do
        let(:pasted) { "https://archyve.openai.azure.com/" }

        it { is_expected.to eq("https://archyve.openai.azure.com") }
      end

      context "with a classic deployment Target URI" do
        let(:pasted) do
          "https://archyve.openai.azure.com/openai/deployments/gpt-4o/chat/completions?api-version=2024-10-21"
        end

        it { is_expected.to eq("https://archyve.openai.azure.com") }
      end

      context "with a v1 base" do
        let(:pasted) { "https://archyve.services.ai.azure.com/openai/v1/" }

        it { is_expected.to eq("https://archyve.services.ai.azure.com") }
      end

      context "with a Foundry project endpoint" do
        let(:pasted) { "https://archyve.services.ai.azure.com/api/projects/archyve" }

        it { is_expected.to eq("https://archyve.services.ai.azure.com") }
      end
    end

    describe "#llm_context" do
      subject(:config) { create(:azure_server, api_key: "azure-live").llm_context.config }

      # A bare resource URL would send RubyLLM to the Foundry model-inference
      # route rather than v1.
      it "points RubyLLM at the v1 API" do
        expect(config.azure_api_base).to eq("https://archyve-test.openai.azure.com/openai/v1")
      end

      it "puts the key on the azure key" do
        expect(config.azure_api_key).to eq("azure-live")
      end
    end

    describe "#available_models" do
      subject(:discovered) { server.available_models }

      let(:server) { create(:azure_server) }
      let(:connection) { instance_double(RubyLLM::Connection, get: nil) }

      before do
        allow(RubyLLM::Provider).to receive(:resolve).with(:azure)
          .and_return(class_double(RubyLLM::Providers::Azure, new: instance_double(
            RubyLLM::Providers::Azure, connection:
          )))
      end

      it "reports nothing, since deployments can't be listed" do
        expect(discovered).to eq([])
      end

      it "still calls the server, so a check proves the address and key" do
        discovered
        expect(connection).to have_received(:get).with("models")
      end

      context "when the key is rejected" do
        before { allow(connection).to receive(:get).and_raise(RubyLLM::UnauthorizedError, "bad key") }

        it "fails the check" do
          expect(server.check!).to be(false)
        end
      end
    end

    describe "#describe_deployment" do
      subject(:discovered) { server.describe_deployment("prod-chat") }

      let(:server) { create(:azure_server) }
      let(:context) { instance_double(RubyLLM::Context, chat:) }
      let(:chat) { instance_double(RubyLLM::Chat) }

      before do
        allow(server).to receive(:llm_context).and_return(context)
        allow(chat).to receive(:ask).and_return(instance_double(RubyLLM::Message, model_id:))
      end

      context "with a chat deployment of a model RubyLLM recognises" do
        let(:model_id) { "gpt-4o-2024-11-20" }

        it "files it as chat" do
          expect(discovered.kind).to eq(:chat)
        end

        it "keeps the deployment name, which is what requests are sent to" do
          expect(discovered.name).to eq("prod-chat")
        end

        it "reads tool support from the model behind the deployment" do
          expect(discovered.supports_tools).to be(true)
        end

        it "reads the context window from the model behind the deployment" do
          expect(discovered.context_window).to eq(128_000)
        end
      end

      context "with a chat deployment of a model RubyLLM doesn't recognise" do
        let(:model_id) { "some-unreleased-model-2026-09-22" }

        it "files it as chat, since it answered a chat request" do
          expect(discovered.kind).to eq(:chat)
        end

        it "reports tool support as unknown rather than false" do
          expect(discovered.supports_tools).to be_nil
        end
      end

      context "with an embedding deployment" do
        let(:model_id) { nil }

        before do
          allow(chat).to receive(:ask).and_raise(RubyLLM::BadRequestError, "OperationNotSupported")
          allow(context).to receive(:embed)
            .and_return(instance_double(RubyLLM::Embedding, vectors: Array.new(768, 0.0)))
        end

        it "files it as embedding" do
          expect(discovered.kind).to eq(:embedding)
        end

        it "measures its dimensions" do
          expect(discovered.dimensions).to eq(768)
        end
      end
    end
  end

  # Removing a server takes its models with it, so the rule protecting the
  # archive's embedder has to hold here too — the cascade must not get around
  # what the model itself refuses.
  describe "removing a server whose model the corpus depends on" do
    subject(:removal) { server.destroy }

    let(:server) { create(:ollama_server) }
    let!(:embedder) { create(:embedding_model, inference_server: server, name: "nomic-embed-text:v1.5") }
    let!(:chat_model) { create(:inference_model, inference_server: server, kind: :chat, name: "gpt-oss:20b") }

    before { create_list(:embedding, 3, embedding_model: "nomic-embed-text:v1.5") }

    it "is refused" do
      expect { removal }.not_to change(described_class, :count)
    end

    it "says why" do
      removal
      expect(server.errors.full_messages.to_sentence).to include("3 chunks are embedded")
    end

    # Refused means nothing happened: the cascade rolls back with the rest.
    it "takes none of its models with it" do
      expect { removal }.not_to change(InferenceModel, :count)
    end

    context "when nothing was embedded with its model" do
      before { Embedding.delete_all }

      it "is removed with its models" do
        expect { removal }.to change(InferenceModel, :count).by(-2)
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
