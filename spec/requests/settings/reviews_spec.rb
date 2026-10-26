require "rails_helper"

RSpec.describe "Settings::Reviews", :unauthenticated, type: :request do
  let(:asker) { create(:user, email_address: "asker@example.com") }
  let(:conversation) { create(:conversation, user: asker, title: "Rotating credentials") }

  def turn(question:, answer:, position:, error: nil)
    create(:segment, message: create(:message, conversation:, position:), content: question)
    create(:message, conversation:, role: "assistant", position: position + 1, completed_at: 1.minute.ago, error:)
      .tap { create(:segment, message: it, content: answer) unless error }
  end

  before { sign_in(create(:user, :admin)) }

  describe "GET /settings/review" do
    subject(:request) { get settings_review_path, params: }

    let(:params) { {} }
    let!(:rated) { turn(question: "How often do keys rotate?", answer: "Every 90 days.", position: 1) }
    let!(:unrated) { turn(question: "Who owns the bastion?", answer: "Platform team.", position: 3) }

    before { create(:feedback, message: rated, rating: "down", comment: "It's 30 days now.") }

    context "with no filter chosen" do
      before { request }

      it "shows answers with feedback, and what was said" do
        expect(response.body).to include("How often do keys rotate?", "Every 90 days.", "It&#39;s 30 days now.")
      end

      it "leaves out answers without any" do
        expect(response.body).not_to include("Who owns the bastion?")
      end

      it "doesn't name who asked" do
        expect(response.body).not_to include("asker@example.com")
      end

      it "links to the answer's prose in its chat, past any thinking or searching" do
        expect(response.body).to include(
          settings_review_chat_path(conversation, anchor: "prose_#{ActionView::RecordIdentifier.dom_id(rated.segments.last)}")
        )
      end
    end

    context "when asking for all answers" do
      let(:params) { { feedback: "" } }

      it "includes those without feedback" do
        request
        expect(response.body).to include("Who owns the bastion?")
      end
    end

    context "when asking for failed answers" do
      let(:params) { { feedback: "", outcome: "failed" } }

      before { turn(question: "What is the VPN address?", answer: nil, error: "The model server went away.", position: 5) }

      before { request }

      it "shows them" do
        expect(response.body).to include("The model server went away.")
      end

      it "leaves out the answered ones" do
        expect(response.body).not_to include("Every 90 days.")
      end
    end

    context "when signed in below admin" do
      before { sign_in(create(:user, :operator)) }

      it "refuses" do
        request
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /settings/review/chats/:id" do
    subject(:request) { get settings_review_chat_path(conversation) }

    let!(:answer) { turn(question: "How often do keys rotate?", answer: "Every 90 days.", position: 1) }

    before do
      create(:feedback, message: answer, rating: "up", comment: "Spot on.")
      request
    end

    it "shows the transcript and its feedback" do
      expect(response.body).to include("How often do keys rotate?", "Every 90 days.", "Spot on.")
    end

    it "doesn't name who asked" do
      expect(response.body).not_to include("asker@example.com")
    end

    it "offers no way to change the feedback" do
      expect(response.body).not_to include(conversation_message_feedback_path(conversation, answer))
    end
  end
end
