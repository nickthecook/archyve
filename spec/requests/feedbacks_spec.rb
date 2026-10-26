require "rails_helper"

RSpec.describe "Feedback", type: :request do
  let(:conversation) { create(:conversation, user: current_user) }
  let(:answer) do
    create(:message, conversation:, role: "assistant", position: 2, completed_at:, error:)
  end
  let(:completed_at) { 1.minute.ago }
  let(:error) { nil }

  describe "PATCH /chat/:conversation_id/messages/:message_id/feedback" do
    subject(:request) do
      patch conversation_message_feedback_path(conversation, answer), params:, as: :turbo_stream
    end

    let(:params) { { rating: "up" } }
    let(:saved) { answer.reload.feedback }

    context "when rating an answer" do
      it "records the rating" do
        request
        expect(saved.rating).to eq("up")
      end

      it "swaps the controls in place" do
        request
        expect(response.body).to include(%(target="#{Views::Conversations::Feedback.dom_id(answer)}"))
      end
    end

    context "when pressing the chosen thumb again" do
      let(:params) { { rating: "" } }

      before { create(:feedback, message: answer, rating: "up") }

      it "takes the rating back" do
        expect { request }.to change(Feedback, :count).by(-1)
      end
    end

    context "when commenting without a rating" do
      let(:params) { { comment: "  Missed the 2024 policy.  " } }

      it "records the comment alone" do
        request
        expect(saved).to have_attributes(rating: nil, comment: "Missed the 2024 policy.")
      end
    end

    context "when rating an answer that already has a comment" do
      before { create(:feedback, message: answer, comment: "Missed the 2024 policy.") }

      it "keeps the comment" do
        request
        expect(saved).to have_attributes(rating: "up", comment: "Missed the 2024 policy.")
      end
    end

    context "when clearing a comment" do
      let(:params) { { comment: "" } }

      before { create(:feedback, message: answer, rating: "down", comment: "Wrong.") }

      it "keeps the rating" do
        request
        expect(saved).to have_attributes(rating: "down", comment: nil)
      end
    end

    context "when the comment is too long" do
      let(:params) { { comment: "x" * (Feedback::COMMENT_LIMIT + 1) } }

      it "refuses it" do
        request
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when the answer failed" do
      let(:error) { "The model server went away." }

      it "takes feedback all the same" do
        request
        expect(saved.rating).to eq("up")
      end
    end

    context "when the answer is still being written" do
      let(:completed_at) { nil }

      it "is not found" do
        request
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when it is someone else's conversation" do
      let(:conversation) { create(:conversation) }

      it "is not found" do
        request
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
