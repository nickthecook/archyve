require "rails_helper"

RSpec.describe Chat::Pace do
  subject(:pace) { described_class.new }

  describe "#attributes" do
    context "when several deltas arrive over a second" do
      before do
        allow(Time).to receive(:current).and_return(
          Time.zone.at(0), Time.zone.at(0.5), Time.zone.at(1)
        )
        3.times { pace.tick }
      end

      it "counts a token per delta" do
        expect(pace.attributes[:token_count]).to eq(3)
      end

      # From the first delta, not from the request. The wait before it is the
      # model reading the prompt, and folding that in makes a long conversation
      # look like a slow model.
      it "spans the first delta to the last" do
        expect(pace.attributes[:generation_ms]).to eq(1000)
      end
    end

    # vLLM batches: one event, several tokens, and it says how many. Counting
    # events instead reports every model on such a host at the rate it flushes.
    context "when the server counts the tokens in each delta" do
      before do
        allow(Time).to receive(:current).and_return(Time.zone.at(0), Time.zone.at(1))
        pace.tick(4)
        pace.tick(3)
      end

      it "counts the tokens rather than the deltas" do
        expect(pace.attributes[:token_count]).to eq(7)
      end
    end

    context "when a single delta arrives" do
      before { pace.tick }

      # One token is a count, not a rate. Segment#tokens_per_second reads the
      # zero span as "no rate" rather than dividing by it.
      it "has no span to divide by" do
        expect(pace.attributes[:generation_ms]).to eq(0)
      end
    end

    context "when nothing ever streamed" do
      it "reports no tokens" do
        expect(pace.attributes).to eq(token_count: 0, generation_ms: 0)
      end
    end
  end
end
