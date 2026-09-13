require "rails_helper"

RSpec.describe "Conversations", type: :request do
  # A tool-capable chat model and an embedder, so chat reports itself available.
  let!(:embedding_model) { create(:embedding_model) }
  let!(:chat_model) { create(:inference_model, kind: "chat", supports_tools: true) }

  # The answer is a job; these specs are about what the request does, not what
  # the model says.
  before { allow(Chat::RespondJob).to receive(:perform_later) }

  describe "POST /chat" do
    subject(:request) { post conversations_path, params: }

    let(:params) { { message: "How do we rotate credentials?" } }

    context "when asking a first question" do
      it "starts a conversation" do
        expect { request }.to change(Conversation, :count).by(1)
      end

      it "records the question as the first turn" do
        request
        expect(Conversation.last.messages.first.text).to eq("How do we rotate credentials?")
      end

      it "sets the answer going" do
        request
        expect(Chat::RespondJob).to have_received(:perform_later)
      end

      it "goes to the transcript" do
        request
        expect(response).to redirect_to(conversation_path(Conversation.last))
      end
    end

    context "when scoped to a collection" do
      let(:collection) { create(:collection, name: "Handbook") }
      let(:params) { { message: "anything", c: [collection.slug] } }

      before { create(:collection_user, collection:, user: current_user) }

      it "stores the scope as a spec, not as document ids" do
        request
        expect(Conversation.last.scope).to eq({ "c" => [collection.slug] })
      end

      it "names it on the conversation" do
        request
        expect(Conversation.last.scope_label).to eq("Handbook")
      end
    end

    context "when a model is picked" do
      let(:picked) { create(:inference_model, kind: "chat", supports_tools: true, name: "big-model") }
      let(:params) { { message: "anything", inference_model_id: picked.id } }

      it "asks that model" do
        request
        expect(Conversation.last.inference_model).to eq(picked)
      end
    end

    # The id arrives in a form field, and a model that can't call tools can't
    # search the archive — so the choice is looked up through what chat may
    # offer rather than by id alone.
    context "when the picked model isn't one chat can offer" do
      let(:toolless) { create(:inference_model, kind: "chat", supports_tools: false, name: "no-tools") }
      let(:params) { { message: "anything", inference_model_id: toolless.id } }

      before { create(:inference_model, kind: "chat", supports_tools: true, name: "usable") }

      it "falls back to a model that can" do
        request
        expect(Conversation.last.inference_model).to eq(InferenceModel.default_chat)
      end

      it "does not ask the model that was posted" do
        request
        expect(Conversation.last.inference_model).not_to eq(toolless)
      end
    end

    context "when the question is blank" do
      let(:params) { { message: "   " } }

      it "starts nothing" do
        expect { request }.not_to change(Conversation, :count)
      end
    end
  end

  describe "GET /chat/:id" do
    subject(:request) { get conversation_path(conversation) }

    context "when it is their own conversation" do
      let(:conversation) { create(:conversation, user: current_user, title: "Rotating credentials") }

      it "renders" do
        request
        expect(response).to have_http_status(:ok)
      end

      it "shows the transcript" do
        create(:segment, message: create(:message, conversation:), content: "How do we rotate credentials?")
        request
        expect(response.body).to include("How do we rotate credentials?")
      end

      context "when more than one model can answer" do
        before do
          create(:inference_model, kind: "chat", supports_tools: true, name: "small-model")
          create(:inference_model, kind: "chat", supports_tools: true, name: "big-model")
          request
        end

        it "offers them in the composer" do
          expect(response.body).to include("small-model", "big-model")
        end
      end

      # The state a fresh install is in: one model, nothing to choose between.
      context "when only one model can answer" do
        before { request }

        it "still says which one is about to answer" do
          expect(response.body).to include(chat_model.label)
        end

        it "offers no choice to make" do
          expect(response.body).not_to include('name="inference_model_id"')
        end
      end

      context "when a turn was answered by a model" do
        let(:model) { create(:inference_model, kind: "chat", supports_tools: true, name: "big-model") }

        before do
          message = create(:message, conversation:, role: "assistant", inference_model: model,
                                     completed_at: Time.current)
          create(:segment, message:, content: "Every 90 days.")
          request
        end

        it "says which one" do
          expect(response.body).to include("big-model")
        end
      end

      context "when the model reasoned before answering" do
        before do
          message = create(:message, conversation:, role: "assistant")
          create(:thinking_segment, message:, position: 1, content: "The user wants the rotation window.")
          create(:segment, message:, position: 2, content: "Every 90 days.")
          request
        end

        it "shows the reasoning" do
          expect(response.body).to include("The user wants the rotation window.")
        end

        it "keeps it collapsed" do
          expect(response.body).not_to match(/<details[^>]*\bopen\b/)
        end

        it "labels it as an aside rather than part of the answer" do
          expect(response.body).to include("Thought about this")
        end
      end
    end

    # A conversation is private to its author. Someone else's id is a 404 —
    # which is also the honest answer to whether it exists.
    context "when it belongs to somebody else" do
      let(:conversation) { create(:conversation, user: create(:user), title: "Not yours") }

      it "is not found" do
        request
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /chat/:conversation_id/messages" do
    subject(:request) { post conversation_messages_path(conversation), params: { message: "And the Stripe keys?" } }

    context "when it is their own conversation" do
      let(:conversation) { create(:conversation, user: current_user) }

      it "adds the turn" do
        expect { request }.to change { conversation.messages.count }.by(1)
      end

      it "sets the answer going" do
        request
        expect(Chat::RespondJob).to have_received(:perform_later)
      end
    end

    context "when it belongs to somebody else" do
      let(:conversation) { create(:conversation, user: create(:user)) }

      it "is not found" do
        request
        expect(response).to have_http_status(:not_found)
      end

      it "adds nothing" do
        expect { request }.not_to change(Message, :count)
      end
    end
  end

  describe "POST /chat/:conversation_id/messages, switching model" do
    subject(:request) do
      post conversation_messages_path(conversation), params: { message: "And the Stripe keys?",
                                                               inference_model_id: picked.id }
    end

    let(:was) { create(:inference_model, kind: "chat", supports_tools: true, name: "small-model") }
    let(:picked) { create(:inference_model, kind: "chat", supports_tools: true, name: "big-model") }
    let(:conversation) { create(:conversation, user: current_user, inference_model: was) }

    # Sticky on purpose: a switch that lasted one turn and silently reverted
    # would be a setting that lies about itself the moment you look away.
    it "switches the conversation to it" do
      request
      expect(conversation.reload.inference_model).to eq(picked)
    end

    it "still records the question" do
      request
      expect(conversation.messages.last.text).to eq("And the Stripe keys?")
    end
  end

  describe "DELETE /chat/:id" do
    subject(:request) { delete conversation_path(conversation) }

    context "when it belongs to somebody else" do
      # Created up front: referencing it lazily inside the expect block would
      # be the change the block is watching for.
      let!(:conversation) { create(:conversation, user: create(:user)) }

      it "does not delete it" do
        expect { request }.not_to change(Conversation, :count)
      end
    end
  end

  describe "GET /chat" do
    subject(:request) { get conversations_path }

    context "when no tool-capable chat model is configured" do
      before { chat_model.update!(supports_tools: false) }

      it "still renders" do
        request
        expect(response).to have_http_status(:ok)
      end

      # Only an admin can fix it, so only an admin is told how.
      context "when signed in as an admin" do
        before { sign_in(create(:user, :admin)) }

        it "says where to fix it" do
          request
          expect(response.body).to include("Settings › Inference")
        end
      end

      context "when signed in as a plain user" do
        before { sign_in(create(:user)) }

        it "does not send them somewhere they can't go" do
          request
          expect(response.body).not_to include("Settings › Inference")
        end
      end
    end
  end
end
