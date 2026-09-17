require "rails_helper"

RSpec.describe Chat::Ask do
  describe ".call" do
    subject(:ask) { described_class.call(conversation, "How do I reset the lock?") }

    let(:conversation) { create(:conversation, inference_model: chat_model) }
    let(:chat_model) { create(:inference_model, kind: "chat", supports_tools: true) }
    let(:messages) { conversation.messages.reload }

    before { allow(Chat::RespondJob).to receive(:perform_later) }

    context "when a question is asked" do
      before { ask }

      it "records the question" do
        expect(messages.first.text).to eq("How do I reset the lock?")
      end

      # The one that matters. The page we redirect to renders whatever exists
      # when it runs, and Chat::Turn only ever *replaces* the turn's element —
      # so if the turn isn't opened here, in this request, the answer streams at
      # an element the page hasn't got and the person has to reload to see it.
      it "opens the turn that will answer it" do
        expect(messages.map(&:role)).to eq(%w[user assistant])
      end

      it "leaves the answer in progress, so the page shows it working" do
        expect(messages.last).to be_in_progress
      end

      it "stamps the answer with the model being asked" do
        expect(messages.last.inference_model).to eq(chat_model)
      end

      it "hands the job both halves" do
        expect(Chat::RespondJob).to have_received(:perform_later).with(messages.first, messages.last)
      end
    end

    # Switching model is sticky: it holds for this question and every one after
    # it, until the person switches again.
    context "when the question picks a different model" do
      subject(:ask) { described_class.call(conversation, "How do I reset the lock?", model: other_model) }

      let(:other_model) { create(:inference_model, kind: "chat", supports_tools: true) }

      before { ask }

      it "moves the conversation to it" do
        expect(conversation.reload.inference_model).to eq(other_model)
      end

      it "stamps the answer with it rather than the one being left behind" do
        expect(messages.last.inference_model).to eq(other_model)
      end
    end

    # An ordinary state on a fresh install, not an error. The turn still opens,
    # so there is somewhere for Chat::Responder to say what's missing.
    context "when no chat model is configured" do
      let(:conversation) { create(:conversation, inference_model: nil) }

      before { ask }

      it "opens the turn anyway" do
        expect(messages.map(&:role)).to eq(%w[user assistant])
      end

      it "leaves it unattributed rather than guessing" do
        expect(messages.last.inference_model).to be_nil
      end
    end

    # solid_queue runs in another process: a job enqueued mid-transaction can be
    # picked up before the rows it names are visible, which fails as a
    # mystifying RecordNotFound under load and never in development.
    context "when the job is enqueued" do
      it "does so after the rows are committed" do
        allow(Chat::RespondJob).to receive(:perform_later) do |question, answer|
          expect(Message.where(id: [question.id, answer.id]).count).to eq(2)
        end

        ask
        expect(Chat::RespondJob).to have_received(:perform_later)
      end
    end

    context "when a conversation already has turns in it" do
      before do
        create(:message, conversation:, position: 1)
        create(:message, conversation:, role: "assistant", position: 2)
        ask
      end

      it "positions both new messages after them" do
        expect(messages.last(2).map(&:position)).to eq([3, 4])
      end
    end
  end
end
