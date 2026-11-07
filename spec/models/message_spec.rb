require "rails_helper"

RSpec.describe Message do
  describe "#tokens_per_second" do
    subject(:message) { create(:message, role: "assistant", position: 2) }

    context "when a turn wrote prose either side of a search" do
      before do
        create(:segment, message:, position: 1, token_count: 30, generation_ms: 1000)
        create(:retrieval_segment, message:, position: 2)
        create(:segment, message:, position: 3, token_count: 30, generation_ms: 500)
      end

      # Sixty tokens over the 1.5s the model spent generating them. However long
      # the search took, and however long the model spent re-reading what it
      # returned, is in neither span — which is what makes this the model's rate
      # rather than the turn's wall clock.
      it "counts only the time the model spent generating" do
        expect(message.tokens_per_second).to eq(40.0)
      end
    end

    context "when the turn only searched" do
      before { create(:retrieval_segment, message:, position: 1) }

      it "has no rate" do
        expect(message.tokens_per_second).to be_nil
      end
    end

    context "when the turn is from before this was recorded" do
      before { create(:segment, message:, position: 1, token_count: nil, generation_ms: nil) }

      it "has no rate" do
        expect(message.tokens_per_second).to be_nil
      end
    end

    # vLLM counts the tokens on its reasoning channel and not on its answer, so
    # a turn can hold one segment of each. Reporting the pair as a rate would
    # divide the answer's seconds by the reasoning's tokens alone.
    context "when one segment streamed uncounted" do
      before do
        create(:thinking_segment, message:, position: 1, token_count: 78, generation_ms: 1000)
        create(:segment, message:, position: 2, token_count: nil, generation_ms: 4000)
      end

      it "has no rate" do
        expect(message.tokens_per_second).to be_nil
      end
    end
  end

  describe "broadcasting whether its conversation can be deleted" do
    let(:conversation) { create(:conversation) }
    let(:stream) { [conversation.user, :conversations] }
    let(:target) { Views::Conversations::DeleteButton.dom_id(conversation) }

    before { allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to) }

    context "when an answer opens" do
      before { create(:message, conversation:, role: "assistant", position: 2) }

      it "disables the button" do
        expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
          .with(*stream, target:, html: include("Still answering"))
      end

      it "disables the conversation's own button too" do
        expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
          .with(conversation, target:, html: include("Still answering"))
      end
    end

    context "when an answer completes" do
      let!(:answer) { create(:message, conversation:, role: "assistant", position: 2) }

      before { answer.update!(completed_at: Time.current) }

      it "enables the button" do
        expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
          .with(*stream, target:, html: satisfy { !it.include?("Still answering") })
      end
    end

    context "when a question is asked" do
      before { create(:message, conversation:) }

      it "broadcasts nothing" do
        expect(Turbo::StreamsChannel).not_to have_received(:broadcast_replace_to)
      end
    end
  end
end
