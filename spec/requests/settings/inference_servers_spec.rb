require "rails_helper"

RSpec.describe "Settings::InferenceServers", :unauthenticated, type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in(admin) }

  describe "GET /settings/inference_servers" do
    subject(:request) { get settings_inference_servers_path }

    context "with no servers configured" do
      # The state a fresh clone is in: nothing is seeded unless
      # OLLAMA_API_BASE is set.
      it "renders" do
        request
        expect(response).to have_http_status(:ok)
      end

      it "says nothing is configured" do
        request
        expect(response.body).to include("No inference servers yet")
      end
    end

    context "with a server" do
      before { create(:ollama_server, name: "tensor") }

      it "lists it" do
        request
        expect(response.body).to include("tensor")
      end
    end
  end

  describe "GET /settings/inference_servers/:id" do
    subject(:request) { get settings_inference_server_path(server) }

    let(:server) { create(:ollama_server, name: "tensor") }

    context "with a chat model" do
      let!(:model) { create(:inference_model, inference_server: server, name: "gpt-oss:20b") }

      it "lists it" do
        request
        expect(response.body).to include("gpt-oss:20b")
      end

      # The row used to make the name itself the edit link, which nobody found.
      it "offers an Edit link beside Remove" do
        request
        expect(response.body).to include(
          %(<a href="#{edit_settings_inference_server_model_path(server, model)}")
        )
      end
    end

    # It used to be a line of faint text below the models, which read as a
    # caption rather than a control. Confirmed because it destroys — see the
    # accent ladder in docs/design.md.
    it "offers removing the server as a confirmed action" do
      request
      expect(response.body).to include("data-turbo-confirm").and include("Remove “tensor” and its models?")
    end

    context "when the corpus depends on this server's embedding model" do
      before do
        create(:embedding_model, inference_server: server, name: "nomic-embed-text:v1.5")
        create(:embedding, embedding_model: "nomic-embed-text:v1.5")
      end

      it "offers no way to remove it" do
        request
        expect(response.body).not_to include("data-turbo-confirm")
      end
    end

    # One embedding model per archive, so a server that isn't holding it is
    # ordinary rather than broken.
    context "when another server holds the embedding model" do
      before do
        create(:embedding_model, inference_server: create(:ollama_server, name: "elsewhere"))
      end

      it "says where it is" do
        request
        expect(response.body).to include("elsewhere")
      end

      it "doesn't claim search is down" do
        request
        expect(response.body).not_to include("search can't run")
      end
    end

    # The name is the only way back: a replacement has to claim it exactly.
    context "when the corpus outlived its embedding model" do
      before { create(:embedding, embedding_model: "nomic-embed-text:v1.5") }

      it "names what the vectors were embedded with" do
        request
        expect(response.body).to include("nomic-embed-text:v1.5")
      end
    end
  end

  describe "GET /settings/inference_servers/new" do
    context "without a type" do
      subject(:request) { get new_settings_inference_server_path }

      it "offers the choice of provider" do
        request
        expect(response.body).to include("Ollama").and include("OpenAI")
      end
    end

    context "with a type" do
      subject(:request) { get new_settings_inference_server_path(type: "InferenceServers::Ollama") }

      it "renders that type's form" do
        request
        expect(response).to have_http_status(:ok)
      end
    end

    # One API, several servers behind it — see docs/architecture.md. Offered
    # only where the distinction exists; Ollama is only ever itself.
    context "with a type whose server could be one of several" do
      subject(:request) { get new_settings_inference_server_path(type: "InferenceServers::OpenAI") }

      it "offers the software it can tell apart" do
        request
        expect(response.body).to include("vLLM").and include("Detect automatically")
      end
    end

    context "with a type that is only ever itself" do
      subject(:request) { get new_settings_inference_server_path(type: "InferenceServers::Ollama") }

      it "asks nothing about software" do
        request
        expect(response.body).not_to include("Detect automatically")
      end
    end

    context "with a type that isn't a server at all" do
      subject(:request) { get new_settings_inference_server_path(type: "User") }

      # `constantize` on user input would otherwise instantiate any class in the
      # app. Same guard SourcesController uses. Rails maps BadRequest to a 400
      # rather than letting it escape the request.
      it "is refused" do
        request
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe "POST /settings/inference_servers" do
    subject(:request) do
      post settings_inference_servers_path, params: { type:, inference_server: attributes }
    end

    let(:type) { "InferenceServers::Ollama" }

    context "with a name and address" do
      let(:attributes) { { name: "tensor", base_url: "http://tensor:11434/v1" } }

      it "creates the server" do
        expect { request }.to change(InferenceServer, :count).by(1)
      end

      it "stores the address as the root" do
        request
        expect(InferenceServer.last.base_url).to eq("http://tensor:11434")
      end
    end

    context "without an address" do
      let(:attributes) { { name: "tensor", base_url: "" } }

      it "doesn't create it" do
        expect { request }.not_to change(InferenceServer, :count)
      end

      it "re-renders the form" do
        request
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when the provider needs a key and none is given" do
      let(:type) { "InferenceServers::OpenAI" }
      let(:attributes) { { name: "OpenAI", api_key: "" } }

      it "doesn't create it" do
        expect { request }.not_to change(InferenceServer, :count)
      end
    end
  end

  describe "PATCH /settings/inference_servers/:id" do
    subject(:request) do
      patch settings_inference_server_path(server), params: { inference_server: attributes }
    end

    let(:server) { create(:openai_server, api_key: "sk-original") }

    context "when the key field is left blank" do
      let(:attributes) { { name: "Renamed", api_key: "" } }

      # The form never echoes the stored key, so a blank submission has to mean
      # "leave it alone" — otherwise editing the name would wipe the credential.
      it "keeps the existing key" do
        request
        expect(server.reload.api_key).to eq("sk-original")
      end

      it "still applies the other changes" do
        request
        expect(server.reload.name).to eq("Renamed")
      end
    end

    context "when a new key is given" do
      let(:attributes) { { api_key: "sk-replaced" } }

      it "replaces it" do
        request
        expect(server.reload.api_key).to eq("sk-replaced")
      end
    end

    context "when the software is chosen by hand" do
      let(:attributes) { { flavour: "vllm" } }

      it "overrules what detection found" do
        request
        expect(server.reload).to be_vllm
      end
    end

    # Unlike the key, a blank here is an answer: "go back to detecting it".
    context "when the software is set back to automatic" do
      let(:attributes) { { flavour: "" } }

      before { server.update!(flavour: "vllm") }

      it "stops overruling detection" do
        request
        expect(server.reload.flavour).to be_blank
      end
    end

    context "when a flavour is posted to a server that has none" do
      let(:server) { create(:ollama_server) }
      let(:attributes) { { name: "Renamed", flavour: "vllm" } }

      # Permitted per type, so an attribute the row has no accessor for is
      # dropped rather than raising its way to a 500.
      it "is ignored" do
        request
        expect(server.reload.name).to eq("Renamed")
      end
    end
  end

  describe "DELETE /settings/inference_servers/:id" do
    subject(:request) { delete settings_inference_server_path(server) }

    let(:server) { create(:ollama_server, name: "tensor") }

    context "with only chat models" do
      before { create(:inference_model, inference_server: server, kind: :chat) }

      it "removes it" do
        expect { request }.to change(InferenceServer, :count).by(-1)
      end
    end

    # Hiding the button is a claim about the page. The cascade would take the
    # archive's embedder with it, and nothing can re-embed yet.
    context "when the cascade would take the corpus's embedder" do
      before do
        create(:embedding_model, inference_server: server, name: "nomic-embed-text:v1.5")
        create(:embedding, embedding_model: "nomic-embed-text:v1.5")
      end

      it "refuses" do
        expect { request }.not_to change(InferenceServer, :count)
      end

      it "says why" do
        request
        follow_redirect!
        expect(response.body).to include("1 chunk is embedded with nomic-embed-text:v1.5")
      end
    end
  end

  describe "POST /settings/inference_servers/:id/check" do
    subject(:request) { post check_settings_inference_server_path(server) }

    let(:server) { create(:ollama_server) }

    context "when the server answers" do
      before { allow_any_instance_of(InferenceServers::Ollama).to receive(:available_models).and_return([]) }

      it "reports success" do
        request
        expect(flash[:notice]).to include("answered")
      end
    end

    context "when the server is unreachable" do
      before do
        allow_any_instance_of(InferenceServers::Ollama)
          .to receive(:available_models).and_raise(Faraday::ConnectionFailed, "refused")
      end

      # A bad address is the thing this button exists to find, so it has to
      # report rather than 500.
      it "reports the failure" do
        request
        expect(flash[:alert]).to include("Couldn't reach")
      end

      it "redirects rather than erroring" do
        request
        expect(response).to redirect_to(settings_inference_server_path(server))
      end
    end
  end

  describe "GET /settings/inference_servers/:id/discover" do
    subject(:request) { get discover_settings_inference_server_path(server) }

    # Scoped to one row on purpose: asserting against the whole page let text
    # from a neighbouring row satisfy a claim about this one.
    def row_for(name)
      response.body[/data-name="#{Regexp.escape(name)}".*?<\/label>/m].to_s
    end

    let(:server) { create(:ollama_server) }
    let(:discovered) do
      [
        InferenceServer::Discovered.new(name: "gemma4:latest", kind: :chat, context_window: 131_072, supports_tools: true),
        InferenceServer::Discovered.new(name: "nomic-embed-text:v1.5", kind: :embedding, dimensions: 768),
        InferenceServer::Discovered.new(name: "mystery:latest", supports_tools: true),
        InferenceServer::Discovered.new(name: "toolless:latest", kind: :chat, supports_tools: false)
      ]
    end

    before do
      allow_any_instance_of(InferenceServers::Ollama).to receive(:available_models).and_return(discovered)
    end

    it "lists what the server reported" do
      request
      expect(response.body).to include("gemma4:latest").and include("mystery:latest")
    end

    # An OpenAI-compatible endpoint can't say what a model is for, and neither
    # can Ollama if /api/show failed. The picker asks rather than guessing.
    it "offers a kind picker for a model it couldn't classify" do
      request
      expect(response.body).to include("kinds[mystery:latest]")
    end

    # Archyve hands the model retrieval as a tool, so a chat model that can't
    # call one can never reach the archive — there is nothing to import.
    it "refuses a chat model that can't call tools" do
      request
      expect(row_for("toolless:latest")).to include("Can&#39;t call tools")
    end

    # The exemption that matters: an embedder is asked for a vector and calls
    # nothing, so the tool rule must not touch the one model the archive can't
    # work without.
    it "still allows an embedding model, which never calls tools" do
      request
      expect(row_for("nomic-embed-text:v1.5")).not_to include("Can&#39;t call tools")
    end

    it "leaves that embedding model tickable" do
      request
      expect(row_for("nomic-embed-text:v1.5")).not_to include("disabled")
    end

    context "when the provider only infers tool support" do
      let(:server) { create(:openai_server) }
      let(:discovered) do
        [
          InferenceServer::Discovered.new(name: "gpt-5.6-luna", context_window: 128_000, supports_tools: true),
          InferenceServer::Discovered.new(name: "some-unreleased-model")
        ]
      end

      before do
        allow_any_instance_of(InferenceServers::OpenAI).to receive(:available_models).and_return(discovered)
      end

      # Discovery's answer is taken as fact and carried through the form; the
      # page never asks the person to confirm it.
      it "carries the discovered tool support without asking" do
        request
        expect(row_for("gpt-5.6-luna")).to include(%(type="hidden" name="supports_tools[gpt-5.6-luna]"))
      end

      it "offers no checkbox to override it" do
        request
        expect(row_for("gpt-5.6-luna")).not_to include(%(type="checkbox" name="supports_tools))
      end

      # The one it couldn't pattern-match is the ordinary case on a vLLM or
      # LM Studio host, where no id looks like OpenAI's. Refusing those on a
      # silence rather than a "no" left the whole server unimportable.
      it "says tool support is unknown" do
        request
        expect(row_for("some-unreleased-model")).to include("Tool support unknown")
      end

      it "doesn't claim the model can't call tools" do
        request
        expect(row_for("some-unreleased-model")).not_to include("Can&#39;t call tools")
      end

      it "leaves that model tickable" do
        request
        expect(row_for("some-unreleased-model")).not_to include("disabled")
      end

      # Ticking it is the answer, so the row carries tool support the same way
      # a reported one does — there is no second box to tick.
      it "treats importing it as the answer" do
        request
        expect(row_for("some-unreleased-model"))
          .to include(%(type="hidden" name="supports_tools[some-unreleased-model]"))
      end
    end

    describe "the order of the list" do
      let(:discovered) do
        [
          InferenceServer::Discovered.new(name: "z-with-tools", kind: :chat, supports_tools: true),
          InferenceServer::Discovered.new(name: "a-no-tools", kind: :chat, supports_tools: false),
          InferenceServer::Discovered.new(name: "a-skipped", skip_reason: "Archyve has no use for an image model."),
          InferenceServer::Discovered.new(name: "a-with-tools", kind: :chat, supports_tools: true)
        ]
      end

      it "puts what can be imported above what can't" do
        request
        expect(response.body.scan(/data-name="([^"]+)"/).flatten)
          .to eq(["a-with-tools", "z-with-tools", "a-no-tools", "a-skipped"])
      end
    end

    context "when a model is already imported" do
      before { create(:inference_model, inference_server: server, name: "gemma4:latest") }

      it "says so rather than offering it again" do
        request
        expect(response.body).to include("Already imported")
      end
    end

    context "when the corpus is already embedded" do
      before { create(:embedding, embedding_model: "nomic-embed-text:v1.5") }

      it "explains why the embedding model can't be ticked" do
        request
        expect(response.body).to include("re-embed")
      end
    end

    context "when the server is unreachable" do
      before do
        allow_any_instance_of(InferenceServers::Ollama)
          .to receive(:available_models).and_raise(Faraday::ConnectionFailed, "refused")
      end

      it "goes back to the server with the reason" do
        request
        expect(flash[:alert]).to include("refused")
      end
    end

    context "with a server that can't list its models" do
      subject(:request) { get discover_settings_inference_server_path(server, deployment:) }

      let(:server) { create(:azure_server) }
      let(:deployment) { nil }

      before { allow_any_instance_of(InferenceServers::Azure).to receive(:available_models).and_return([]) }

      context "without a deployment name" do
        it "asks for one" do
          request
          expect(response.body).to include("Deployment name")
        end

        it "doesn't claim the server has no models" do
          request
          expect(response.body).not_to include("The server reported no models")
        end
      end

      context "with a deployment that answers" do
        let(:deployment) { " prod-chat " }

        before do
          allow_any_instance_of(InferenceServers::Azure).to receive(:describe_deployment).with("prod-chat")
            .and_return(InferenceServer::Discovered.new(name: "prod-chat", kind: :chat, supports_tools: true))
        end

        it "offers it for import" do
          request
          expect(row_for("prod-chat")).to include(%(name="models[]" value="prod-chat"))
        end

        context "when the model behind it needs Responses" do
          before do
            allow_any_instance_of(InferenceServers::Azure).to receive(:describe_deployment).with("prod-chat")
              .and_return(
                InferenceServer::Discovered.new(name: "prod-chat", kind: :chat, supports_tools: true, protocol: "responses")
              )
          end

          it "carries the protocol through to the import" do
            request
            expect(row_for("prod-chat")).to include(%(name="protocols[prod-chat]" value="responses"))
          end
        end
      end

      context "with a deployment that doesn't exist" do
        let(:deployment) { "nope" }

        before do
          allow_any_instance_of(InferenceServers::Azure).to receive(:describe_deployment)
            .and_raise(RubyLLM::Error, "Resource not found")
        end

        it "says why on the page" do
          request
          expect(response.body).to include("nope didn&#39;t answer: Resource not found")
        end
      end
    end
  end

  describe "POST /settings/inference_servers/:id/import" do
    subject(:request) do
      post import_settings_inference_server_path(server), params: {
        models: ["gemma4:latest"],
        kinds: { "gemma4:latest" => kind },
        context_windows: { "gemma4:latest" => "131072" },
        dimensions: { "nomic-embed-text:v1.5" => "768" },
        supports_tools: { "gemma4:latest" => "1" }
      }
    end

    let(:server) { create(:ollama_server) }
    let(:kind) { "chat" }

    context "with a chat model ticked" do
      it "creates it" do
        expect { request }.to change(InferenceModel, :count).by(1)
      end

      it "carries the capabilities discovery reported" do
        request
        expect(InferenceModel.last).to have_attributes(context_window: 131_072, supports_tools: true)
      end

      it "picks the protocol from the model id" do
        request
        expect(InferenceModel.last.protocol).to eq("chat_completions")
      end
    end

    context "with a protocol discovery worked out" do
      subject(:request) do
        post import_settings_inference_server_path(server), params: {
          models: ["prod-chat"], supports_tools: { "prod-chat" => "1" }, protocols: { "prod-chat" => "responses" }
        }
      end

      let(:server) { create(:azure_server) }

      it "uses it" do
        request
        expect(InferenceModel.last.protocol).to eq("responses")
      end
    end

    context "when the model is already imported" do
      before { create(:inference_model, inference_server: server, name: "gemma4:latest") }

      it "reports the rejection rather than silently skipping it" do
        request
        expect(flash[:alert]).to include("gemma4:latest")
      end
    end

    # The picker greys these rows out and disables their boxes, which is a
    # client-side claim and nothing more. A post that arrives anyway is refused
    # here: a chat model that can't call tools can never reach the archive.
    context "when a chat model arrives without tool support" do
      subject(:request) do
        post import_settings_inference_server_path(server), params: {
          models: ["qwen3.8-27b"], kinds: { "qwen3.8-27b" => "chat" }
        }
      end

      it "doesn't create it" do
        expect { request }.not_to change(InferenceModel, :count)
      end

      it "says why" do
        request
        expect(flash[:alert]).to include("qwen3.8-27b (can't call tools)")
      end
    end

    # The exemption, again: the tool rule must never reach the one model the
    # archive can't work without.
    context "when an embedding model is ticked without tool support" do
      subject(:request) do
        post import_settings_inference_server_path(server), params: {
          models: ["nomic-embed-text:v1.5"],
          kinds: { "nomic-embed-text:v1.5" => "embedding" },
          dimensions: { "nomic-embed-text:v1.5" => "768" }
        }
      end

      it "creates it" do
        expect { request }.to change(InferenceModel, :count).by(1)
      end
    end

    context "when an embedding model is ticked but the corpus is already embedded" do
      let(:kind) { "embedding" }

      before { create(:embedding, embedding_model: "nomic-embed-text:v1.5") }

      # The picker disables these rows, but the model has to refuse too —
      # hiding a control is not enforcement.
      it "doesn't create it" do
        expect { request }.not_to change(InferenceModel, :count)
      end

      it "says why" do
        request
        expect(flash[:alert]).to include("re-embedding")
      end
    end
  end

  describe "DELETE /settings/inference_servers/:id" do
    subject(:request) { delete settings_inference_server_path(server) }

    let(:server) { create(:ollama_server) }

    before { create(:inference_model, inference_server: server) }

    it "removes the server and its models" do
      expect { request }.to change(InferenceModel, :count).by(-1)
    end

    context "when the corpus holds vectors its model produced" do
      before { create(:embedding, embedding_model: "nomic-embed-text:v1.5") }

      # embeddings.embedding_model is a free-text record of what embedded each
      # chunk, not a foreign key — it stays true after the row naming it is gone.
      it "leaves the vectors alone" do
        expect { request }.not_to change(Embedding, :count)
      end
    end
  end
end
