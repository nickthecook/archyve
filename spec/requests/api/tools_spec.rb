require "rails_helper"

RSpec.describe "API tools", type: :request, unauthenticated: true do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user:) }
  let(:headers) { { "Authorization" => "Bearer #{api_key.token}" } }
  let(:body) { response.parsed_body }

  let(:collection) { create(:collection, name: "Reports") }
  let(:readable) { create(:document, title: "Inside Report") }
  let(:unreadable) { create(:document, title: "Outside Memo") }

  before do
    create(:collection_membership, collection:, document: readable, origin: "manual")
    create(:collection_membership, collection: create(:collection), document: unreadable, origin: "manual")
    create(:collection_user, collection:, user:)
  end

  describe "GET /api/tools" do
    subject(:request) { get api_tools_path, headers: }

    it "lists every tool by its chat name" do
      request
      expect(body["tools"].pluck("name")).to eq(%w[search_archive list_collections list_documents read_document])
    end

    it "gives each one an input schema" do
      request
      expect(body["tools"].first["input_schema"]).to include("required" => ["queries"])
    end

    context "without a key" do
      let(:headers) { {} }

      it "is unauthorized" do
        request
        expect(response).to have_http_status(:unauthorized)
      end

      it "says how to authenticate" do
        request
        expect(response.headers["WWW-Authenticate"]).to start_with("Bearer")
      end
    end

    context "with a key that has been deleted" do
      before { api_key.destroy }

      it "is unauthorized" do
        request
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with the key sent under another scheme" do
      let(:headers) { { "Authorization" => "Basic #{api_key.token}" } }

      it "is unauthorized" do
        request
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with a signed-in browser session instead of a key" do
      let(:headers) { {} }

      before { sign_in }

      it "is unauthorized" do
        request
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it "records that the key was used" do
      request
      expect(api_key.reload.last_used_at).to be_within(1.second).of(Time.current)
    end
  end

  describe "POST /api/tools/:name" do
    subject(:request) { post api_tool_path(name), params: arguments, headers:, as: :json }

    context "with a tool that doesn't exist" do
      let(:name) { "drop_tables" }
      let(:arguments) { {} }

      it "is not found" do
        request
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with a body that isn't JSON" do
      subject(:request) do
        post api_tool_path("list_collections"), params: "{nope",
          headers: headers.merge("Content-Type" => "application/json")
      end

      it "is a bad request" do
        request
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "without a key" do
      let(:name) { "list_collections" }
      let(:arguments) { {} }
      let(:headers) { {} }

      it "is unauthorized" do
        request
        expect(response).to have_http_status(:unauthorized)
      end

      it "doesn't run the tool" do
        request
        expect(body).not_to have_key("collections")
      end
    end

    describe "search_archive" do
      let(:name) { "search_archive" }
      let(:arguments) { { queries: ["reports"] } }

      before do
        create(:embedding_model)
        allow(Embeddings::Embed).to receive(:query).and_return(Array.new(Embedding::DIMENSIONS) { 0.1 })
        create(:embedding, chunk: create(:chunk, document: readable, content: "The inside story."))
        create(:embedding, chunk: create(:chunk, document: unreadable))
      end

      it "returns passages from readable documents only" do
        request
        expect(body["results"].map { it.dig("document", "title") }).to eq(["Inside Report"])
      end

      it "returns the passage text" do
        request
        expect(body["results"].first["text"]).to eq("The inside story.")
      end

      context "when scoped to a collection the caller can't read" do
        let(:arguments) { { queries: ["reports"], collections: [unreadable.collections.first.slug] } }

        it "finds nothing rather than refusing" do
          request
          expect(body["results"]).to be_empty
        end
      end

      context "without queries" do
        let(:arguments) { { queries: [] } }

        it "is unprocessable" do
          request
          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      context "with an argument the tool doesn't take" do
        let(:arguments) { { queries: ["reports"], user_id: 1 } }

        it "is unprocessable" do
          request
          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      context "when the embedding server can't be reached" do
        before { allow(Embeddings::Embed).to receive(:query).and_raise(Faraday::ConnectionFailed, "refused") }

        it "is unavailable rather than empty" do
          request
          expect(response).to have_http_status(:service_unavailable)
        end
      end
    end

    describe "list_collections" do
      let(:name) { "list_collections" }
      let(:arguments) { {} }

      it "lists only readable collections" do
        request
        expect(body["collections"].pluck("name")).to eq(["Reports"])
      end
    end

    describe "list_documents" do
      let(:name) { "list_documents" }
      let(:arguments) { { collection: slug } }

      context "with a readable collection" do
        let(:slug) { collection.slug }

        it "lists its documents" do
          request
          expect(body["documents"].pluck("title")).to eq(["Inside Report"])
        end
      end

      context "with a collection the caller can't read" do
        let(:slug) { unreadable.collections.first.slug }

        it "is not found" do
          request
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    describe "recording the call" do
      let(:name) { "list_collections" }
      let(:arguments) { {} }
      let(:recorded) { ApiCall.incoming.sole }

      context "when incoming calls are recorded" do
        before { Setting["debug.record_incoming_api_calls"] = true }

        it "files it under the key and its owner" do
          request
          expect(recorded).to have_attributes(api_key:, user:, service_name: "Script")
        end

        it "redacts the key" do
          request
          expect(recorded.request_headers["Authorization"]).to eq("[REDACTED]")
        end

        it "records what came back" do
          request
          expect(recorded).to have_attributes(response_code: 200, response_body: include("collections"))
        end

        context "without a key" do
          let(:headers) { {} }

          it "records the refusal too" do
            request
            expect(recorded).to have_attributes(response_code: 401, user: nil, service_name: "unauthenticated")
          end
        end

        context "with a body that isn't JSON" do
          subject(:request) do
            post api_tool_path(name), params: "{nope", headers: headers.merge("Content-Type" => "application/json")
          end

          it "records the status the caller got" do
            request
            expect(recorded.response_code).to eq(400)
          end
        end
      end

      context "when only outgoing calls are recorded" do
        before { Setting["debug.record_api_calls"] = true }

        it "records nothing" do
          request
          expect(ApiCall.count).to eq(0)
        end
      end
    end

    describe "read_document" do
      let(:name) { "read_document" }
      let(:arguments) { { document: document.id } }

      context "with a readable document" do
        let(:document) { readable }

        before { create(:chunk, document:, position: 0, content: "First chunk.") }

        it "returns its chunks" do
          request
          expect(body["chunks"]).to eq([{ "chunk" => 1, "text" => "First chunk." }])
        end
      end

      context "with a readable document that hasn't been processed" do
        let(:document) { readable }

        it "is a conflict" do
          request
          expect(response).to have_http_status(:conflict)
        end
      end

      context "with a document the caller can't read" do
        let(:document) { unreadable }

        before { create(:chunk, document:) }

        it "is not found, as a missing one is" do
          request
          expect(body).to eq("error" => "not_found", "message" => "No such document.")
        end
      end

      context "with an id given as a string" do
        let(:arguments) { { document: readable.id.to_s } }

        it "is unprocessable" do
          request
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end
  end
end
