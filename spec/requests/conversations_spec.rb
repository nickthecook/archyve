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
