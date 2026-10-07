require "rails_helper"

RSpec.describe Chat::Context do
  subject(:context) { described_class.new(conversation.reload) }

  let(:conversation) { create(:conversation) }

  describe "#tokens" do
    context "when nothing has been measured yet" do
      # The first turn of a chat has no baseline to build on: the instructions
      # and tool schemas are already in the prompt and nothing here can see them.
      it "starts from nothing rather than guessing at the whole prompt" do
        expect(context.tokens).to eq(0)
      end
    end

    context "with a measured turn behind it" do
      let!(:measured) do
        create(:message, conversation:, role: "assistant", position: 1,
                         input_tokens: 4_000, completed_at: Time.current)
      end

      it "starts from what the server counted" do
        expect(context.tokens).to eq(4_000)
      end

      # That figure covers the prompt the turn was *sent*, so its own answer —
      # which the next prompt carries — is not in it.
      context "when that turn said something" do
        before { create(:segment, message: measured, content: "x" * 800) }

        it "adds what replay will send" do
          expect(context.tokens).to eq(4_200)
        end
      end

      # The measured figure is the prompt of that turn's *last* round, and that
      # round had already been sent every tool result the turn produced.
      # Charging for them again put the guess 45% over on a two-turn chat.
      context "when that turn searched" do
        before do
          segment = create(:retrieval_segment, message: measured, position: 2)
          create(:hit, segment:, snippet: "x" * 2_000)
        end

        it "charges nothing for what the search returned" do
          expect(context.tokens).to eq(4_000)
        end
      end

      # Reasoning is dropped from replay, so none of it reaches a later prompt.
      # Charging for it put the guess 80% over on a live gpt-oss turn.
      context "when that turn reasoned at length" do
        before { create(:thinking_segment, message: measured, content: "x" * 8_000) }

        it "charges nothing for it" do
          expect(context.tokens).to eq(4_000)
        end
      end

      context "when a question has been asked since" do
        before do
          question = create(:message, conversation:, position: 2)
          create(:segment, message: question, content: "x" * 400)
        end

        it "estimates it from its length" do
          expect(context.tokens).to eq(4_100)
        end
      end
    end
  end

  describe "#tick" do
    before { context.tick(12) }

    it "counts what the server said the chunk was worth" do
      expect(context.tokens).to eq(12)
    end
  end

  describe "#absorb" do
    # What a tool costs is not what it printed but what replay will send, which
    # is the question Segment#for_history already answers.
    context "with a search that found nothing" do
      let(:segment) { create(:retrieval_segment, queries: ["rotation"]) }

      it "charges for the line replay will carry" do
        expect { context.absorb(segment) }.to change(context, :tokens).by(
          (segment.for_history.length / 4.0).ceil
        )
      end
    end

    context "with no segment at all" do
      it "charges nothing" do
        expect { context.absorb(nil) }.not_to change(context, :tokens)
      end
    end
  end
end
