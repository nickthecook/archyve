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

    # The picker ticks everything by default and posts a blank c[] alongside
    # whatever is ticked, so these three submissions are the three states it can
    # be in — and "all of them" and "none of them" must not mean the same thing.
    context "when the picker is submitted" do
      let!(:handbook) { create(:collection, name: "Handbook") }
      let!(:runbooks) { create(:collection, name: "Runbooks") }

      before do
        create(:collection_user, collection: handbook, user: current_user)
        create(:collection_user, collection: runbooks, user: current_user)
      end

      context "with every collection ticked" do
        let(:params) { { message: "anything", c: ["", handbook.slug, runbooks.slug] } }

        it "draws on all of them" do
          request
          expect(Conversation.last.scope).to eq({ "c" => [handbook.slug, runbooks.slug] })
        end
      end

      context "with some collections ticked" do
        let(:params) { { message: "anything", c: ["", handbook.slug] } }

        it "narrows to those" do
          request
          expect(Conversation.last.scope).to eq({ "c" => [handbook.slug] })
        end
      end

      context "with nothing ticked" do
        let(:params) { { message: "anything", c: [""] } }

        it "draws on nothing rather than everything" do
          request
          expect(Conversation.last.scope).to eq({ "c" => [] })
        end

        it "starts a chat that does not search" do
          request
          expect(Conversation.last).not_to be_searches_archive
        end
      end
    end

    # The landing bar, and any link that never mentioned collections: no picker
    # was in front of the person, so there is no selection to honour.
    context "when no scope is submitted at all" do
      let!(:collection) { create(:collection, name: "Handbook") }

      before { create(:collection_user, collection:, user: current_user) }

      it "draws on the whole archive" do
        request
        expect(Conversation.last.scope).to eq({})
      end
    end

    context "when no agent is named" do
      it "asks Archivist" do
        request
        expect(Conversation.last.agent).to eq(Agent.archivist)
      end
    end

    context "when an admin starts a chat with Admin Support" do
      let(:params) { { message: "Why are documents stuck?", agent: "admin_support", c: ["handbook"] } }

      before { sign_in(create(:user, :admin)) }

      it "asks Admin Support" do
        request
        expect(Conversation.last.agent).to eq(Agent.admin_support)
      end

      it "draws on no collections, whatever was posted" do
        request
        expect(Conversation.last.scope).to eq("c" => [])
      end
    end

    context "when a curator names Admin Support" do
      let(:params) { { message: "anything", agent: "admin_support" } }

      it "is not found" do
        request
        expect(response).to have_http_status(:not_found)
      end

      it "starts nothing" do
        expect { request }.not_to change(Conversation, :count)
      end
    end

    context "when the agent doesn't exist" do
      let(:params) { { message: "anything", agent: "nobody" } }

      it "is not found" do
        request
        expect(response).to have_http_status(:not_found)
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

    # The top bar links to Chat and Settings too, so match the crumb's own markup.
    def crumb(label, href) = Views::Breadcrumb.new([label, href], "here").call[/<a [^>]*>#{label}<\/a>/]

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

      it "leads back to Chat" do
        request
        expect(response.body).to include(crumb("Chat", conversations_path))
      end

      context "with Admin Support" do
        let(:conversation) { create(:conversation, user: current_user, agent: Agent.admin_support, scope: { "c" => [] }) }

        it "leads back through Settings and Admin" do
          request
          expect(response.body).to include(crumb("Settings", settings_path), crumb("Admin", settings_admin_path))
        end

        it "doesn't lead back to Chat" do
          request
          expect(response.body).not_to include(crumb("Chat", conversations_path))
        end
      end

      describe "feedback on an answer" do
        let!(:answer) { create(:message, conversation:, role: "assistant", position: 2, completed_at:) }
        let(:controls) { %(id="#{Views::Conversations::Feedback.dom_id(answer)}") }

        before { request }

        context "when the answer is finished" do
          let(:completed_at) { 1.minute.ago }

          it "offers it" do
            expect(response.body).to include(controls, "Good answer", "Comment")
          end
        end

        context "when the answer is still being written" do
          let(:completed_at) { nil }

          it "waits until it is done" do
            expect(response.body).not_to include(controls)
          end
        end
      end

      # The fallback for a transcript the cable isn't reaching — a subscription
      # that never came up, a dropped connection, or a second tab that was never
      # sent the turn because another tab's request recorded it.
      describe "the transcript's fallback poll" do
        before do
          create(:message, conversation:, role: "assistant", position: 2, completed_at: completed_at)
          request
        end

        context "while a turn is still in flight" do
          let(:completed_at) { nil }

          it "keeps polling" do
            expect(response.body).to include('data-progress-terminal-value="false"')
          end
        end

        context "once every turn has landed" do
          let(:completed_at) { Time.current }

          it "stops" do
            expect(response.body).to include('data-progress-terminal-value="true"')
          end
        end
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

      context "when the models are spread across servers" do
        before do
          create(:inference_model, :tools, name: "qwen3:8b", inference_server: create(:inference_server, name: "Workshop"))
          request
        end

        it "files each under its server" do
          expect(response.body).to include(%(<optgroup label="Workshop"><option value=))
        end

        it "leaves the model names to themselves" do
          expect(response.body).to include(">qwen3:8b<")
        end
      end

      context "when every model is on one server" do
        before do
          create(:inference_model, :tools, name: "qwen3:8b", inference_server: chat_model.inference_server)
          request
        end

        it "does not group them" do
          expect(response.body).not_to include("<optgroup")
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

      # "Drawing on: no collections" reads as a fault; it was a choice.
      context "when it draws on no collections" do
        let(:conversation) { create(:conversation, :no_collections, user: current_user) }

        it "says the archive isn't being searched" do
          request
          expect(response.body).to include("doesn&#39;t search your archive")
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

      # Two: the question, and the empty turn that will answer it. The answer's
      # row is opened here rather than in the job so that the page this
      # redirects to has an element for the stream to replace — see Chat::Ask.
      it "adds the question and the turn that answers it" do
        expect { request }.to change { conversation.messages.count }.by(2)
      end

      it "renders the waiting turn on the page it redirects to" do
        request
        follow_redirect!
        expect(response.body).to include("Thinking…")
      end

      it "sets the answer going" do
        request
        expect(Chat::RespondJob).to have_received(:perform_later)
      end

      # The redirect is a full page load, and on a phone a conversation of any
      # length puts the new turn below the fold — so landing at the top shows
      # the asker the start of a chat they have already read.
      it "lands on the question just asked rather than the top of the page" do
        request
        question = conversation.messages.user.last
        expect(response).to redirect_to(conversation_path(conversation, anchor: "message_#{question.id}"))
      end
    end

    # Nothing was asked, so there is nothing to land on.
    context "when the box was empty" do
      let(:conversation) { create(:conversation, user: current_user) }

      it "goes back to the transcript without an anchor" do
        post conversation_messages_path(conversation), params: { message: "   " }
        expect(response).to redirect_to(conversation_path(conversation))
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
      expect(conversation.messages.first.text).to eq("And the Stripe keys?")
    end

    it "stamps the turn with the model that was picked" do
      request
      expect(conversation.messages.last.inference_model).to eq(picked)
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

    # The picker has to show what a chat would actually search, and by default
    # that is everything — so every box arrives ticked.
    context "when collections are readable" do
      let!(:handbook) { create(:collection, name: "Handbook") }
      let!(:runbooks) { create(:collection, name: "Runbooks") }

      before do
        create(:collection_user, collection: handbook, user: current_user)
        create(:collection_user, collection: runbooks, user: current_user)
      end

      it "ticks them all" do
        request
        expect(response.body).to match(/value="#{handbook.slug}"[^>]*\bchecked\b/)
          .and match(/value="#{runbooks.slug}"[^>]*\bchecked\b/)
      end

      # Without it, unticking everything would post no c[] at all, which the
      # wire format reads as All.
      it "posts an empty selection even when nothing is ticked" do
        request
        expect(response.body).to include('<input type="hidden" name="c[]" value="">')
      end

      context "when the page is opened already narrowed" do
        subject(:request) { get conversations_path, params: { c: [handbook.slug] } }

        it "ticks what the link named" do
          request
          expect(response.body).to match(/value="#{handbook.slug}"[^>]*\bchecked\b/)
        end

        it "leaves the rest alone" do
          request
          expect(response.body).not_to match(/value="#{runbooks.slug}"[^>]*\bchecked\b/)
        end
      end
    end

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

      context "when signed in as a visitor" do
        before { sign_in(create(:user)) }

        it "does not send them somewhere they can't go" do
          request
          expect(response.body).not_to include("Settings › Inference")
        end
      end
    end
  end
end
