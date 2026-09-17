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
  end
end
