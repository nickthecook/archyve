require "rails_helper"

RSpec.describe Chat::SweepHungTurnsJob do
  subject(:job) { described_class.new }

  let(:conversation) { create(:conversation) }
  let(:result) { job.perform }

  describe "#perform" do
    context "with an answer that never produced anything" do
      let!(:turn) do
        create(:message, conversation:, role: "assistant", position: 2,
          completed_at: nil, created_at: 2.hours.ago)
      end

      it "stops the page waiting on it" do
        result
        expect(turn.reload).not_to be_in_progress
      end

      it "says the answer stopped partway" do
        result
        expect(turn.reload.error).to eq(Message::ABANDONED)
      end
    end

    context "with an answer whose last segment went quiet" do
      let!(:turn) do
        create(:message, conversation:, role: "assistant", position: 2, completed_at: nil)
      end

      before do
        create(:segment, message: turn, position: 1, updated_at: 2.hours.ago)
      end

      it "abandons it" do
        result
        expect(turn.reload).not_to be_in_progress
      end
    end

    context "with a long answer that is still streaming" do
      let!(:turn) do
        create(:message, conversation:, role: "assistant", position: 2,
          completed_at: nil, created_at: 6.hours.ago)
      end

      # The turn opened hours ago and is still writing. Judged on the segment,
      # it is alive; judged on created_at it would be swept mid-sentence.
      before do
        create(:segment, message: turn, position: 1, updated_at: 1.minute.ago)
      end

      it "leaves it alone" do
        result
        expect(turn.reload).to be_in_progress
      end
    end

    context "with an answer that failed on its own and never completed" do
      let!(:turn) do
        create(:message, conversation:, role: "assistant", position: 2, completed_at: nil,
          created_at: 2.hours.ago, error: "Couldn't reach Ollama. Check that it's running.")
      end

      it "keeps the original error rather than overwriting it" do
        result
        expect(turn.reload.error).to eq("Couldn't reach Ollama. Check that it's running.")
      end
    end

    context "with an unanswered question" do
      let!(:turn) do
        create(:message, conversation:, role: "user", position: 1, created_at: 2.hours.ago)
      end

      # A person's turn is complete the moment it exists, so it has no
      # completed_at to fill in and nothing is waiting on it.
      it "leaves it alone" do
        result
        expect(turn.reload.completed_at).to be_nil
      end
    end

    context "with a finished answer" do
      let!(:turn) do
        completed = 2.hours.ago
        create(:message, conversation:, role: "assistant", position: 2,
          created_at: completed, completed_at: completed)
      end

      it "leaves its error alone" do
        result
        expect(turn.reload.error).to be_nil
      end
    end
  end
end
