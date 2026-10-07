require "rails_helper"

RSpec.describe Views::Conversations::ContextMeter do
  describe "#call" do
    subject(:meter) { described_class.new(conversation:).call }

    let(:conversation) { create(:conversation) }
    let(:model) { create(:inference_model, :tools, context_window: 131_072) }

    # The empty turn Chat::Ask opens is filled in by Chat::Turn, which writes
    # input_tokens as it closes — so a measured turn is a completed one.
    def answered(input_tokens:, window: 131_072)
      create(
        :message, conversation:, role: "assistant", position: 2,
        inference_model: create(:inference_model, :tools, context_window: window),
        input_tokens: input_tokens, completed_at: Time.current
      )
    end

    # Just the text, which is what someone glancing at the row reads.
    let(:reading) { meter.gsub(/<[^>]*>/, " ").squish }

    # The element has to be on the page regardless: Chat::Turn replaces it by
    # id, and a target the page doesn't have is a broadcast that lands nowhere.
    it "renders the element the turn broadcasts to" do
      expect(meter).to include(%(id="context_conversation_#{conversation.id}"))
    end

    context "when nothing has been asked yet" do
      it "shows no reading" do
        expect(reading).to be_empty
      end
    end

    context "when the server reported what the prompt cost" do
      before { answered(input_tokens: 12_431) }

      it "reads the turn against the window" do
        expect(reading).to eq("Context 12.4k / 131.1k")
      end

      it "fills the bar by that share" do
        expect(meter).to include("width: 9.48%")
      end
    end

    # The window belongs to the model that answered, not to whichever one the
    # picker is showing now — a person who switches mid-chat would otherwise see
    # the last turn measured against a window it was never sent to.
    context "when the person has since switched model" do
      before do
        answered(input_tokens: 3_000, window: 8_192)
        conversation.update!(inference_model: model)
      end

      it "measures against the window the turn was answered with" do
        expect(reading).to eq("Context 3k / 8.2k")
      end
    end

    context "when the model reported no usage" do
      before do
        create(:message, conversation:, role: "assistant", position: 2,
                         inference_model: model, completed_at: Time.current)
      end

      it "shows no reading rather than claiming zero" do
        expect(reading).to be_empty
      end
    end

    context "when nobody filled in the model's context window" do
      before { answered(input_tokens: 12_431, window: nil) }

      it "shows no reading rather than a ratio of nothing" do
        expect(reading).to be_empty
      end
    end

    # The server reports a prompt size only when a turn ends, so a turn in flight
    # shows Chat::Context's guess — marked, because it visibly jumps when the
    # real figure lands and an unmarked jump reads as a glitch.
    context "while the turn is still running" do
      before do
        create(:message, conversation:, role: "assistant", position: 2,
                         inference_model: model, input_tokens: 12_431, completed_at: nil)
      end

      it "marks the reading as a guess" do
        expect(reading).to eq("Context ~12.4k / 131.1k")
      end

      it "fills the bar anyway" do
        expect(meter).to include("width: 9.48%")
      end

      it "says so at length in the title" do
        expect(meter).to include("reports the real figure when the turn ends")
      end
    end

    context "once the turn has closed" do
      before { answered(input_tokens: 12_431) }

      it "drops the mark" do
        expect(reading).not_to include("~")
      end
    end

    describe "the bands" do
      {
        "under half the window" => [40_000, "bg-emerald-600"],
        "past half" => [80_000, "bg-accent"],
        "past four fifths" => [120_000, "bg-red-400"]
      }.each do |description, (tokens, colour)|
        context "when the prompt is #{description}" do
          before { answered(input_tokens: tokens) }

          it "fills #{colour}" do
            expect(meter).to include(colour)
          end
        end
      end
    end

    # A server started with a shorter window than Archyve was told reports a
    # prompt that overflows it. The reading stays honest; the bar can't.
    context "when the prompt overflows the window Archyve knows about" do
      before { answered(input_tokens: 200_000) }

      it "says what the server counted" do
        expect(reading).to eq("Context 200k / 131.1k")
      end

      it "keeps the fill inside its track" do
        expect(meter).to include("width: 100%")
      end
    end
  end
end
