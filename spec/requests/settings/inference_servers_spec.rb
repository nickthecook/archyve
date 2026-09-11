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
        expect(response).to have_http_status(:unprocessable_entity)
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

    let(:server) { create(:ollama_server) }
    let(:discovered) do
      [
        InferenceServer::Discovered.new(name: "gemma4:latest", kind: :chat, context_window: 131_072, supports_tools: true),
        InferenceServer::Discovered.new(name: "nomic-embed-text:v1.5", kind: :embedding, dimensions: 768),
        InferenceServer::Discovered.new(name: "mystery:latest")
      ]
    end

    before do
      allow_any_instance_of(InferenceServers::Ollama).to receive(:available_models).and_return(discovered)
    end

    it "lists what the server reported" do
      request
      expect(response.body).to include("gemma4:latest").and include("mystery:latest")
    end

    it "marks a model that can call tools" do
      request
      expect(response.body).to include("tools")
    end

    # An OpenAI-compatible endpoint can't say what a model is for, and neither
    # can Ollama if /api/show failed. The picker asks rather than guessing.
    it "offers a kind picker for a model it couldn't classify" do
      request
      expect(response.body).to include("kinds[mystery:latest]")
    end

    # Ollama declares capabilities, so its rows state tool support.
    it "doesn't ask about tools when the server declares them" do
      request
      expect(response.body).not_to include("supports_tools[gemma4:latest]\" type=\"checkbox")
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

      # The person adding the model usually knows better than a pattern match
      # on its id, and this is what decides whether it can do retrieval at all.
      it "offers tool support as a ticked box rather than a fact" do
        request
        expect(response.body).to include(%(name="supports_tools[gpt-5.6-luna]"))
      end

      it "says so when the guess has nothing behind it" do
        request
        expect(response.body).to include("this is a guess")
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
    end

    context "when the model is already imported" do
      before { create(:inference_model, inference_server: server, name: "gemma4:latest") }

      it "reports the rejection rather than silently skipping it" do
        request
        expect(flash[:alert]).to include("gemma4:latest")
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
