require "rails_helper"

RSpec.describe Views::Conversations::Thinking do
  describe "#call" do
    subject(:thinking) { described_class.new(segment:) }

    # Just the numbers at the end of the summary row, with the markup between
    # them stripped out, which is what someone glancing at the row reads. The
    # count is glued to its unit with a non-breaking space, so "3 words" can't
    # split across lines — spelled out here rather than pasted in invisibly.
    let(:tally) { thinking.call[/<summary.*?<\/summary>/m].gsub(/<[^>]*>/, "").strip }
    let(:nbsp) { "\u00A0" }

    context "while the model is still reasoning" do
      let(:segment) { create(:thinking_segment, content: "One two three.") }

      # Nothing has been measured yet, so nothing is claimed — not a zero.
      it "counts the words alone" do
        expect(tally).to end_with("3#{nbsp}words")
      end
    end

    context "once the segment is complete" do
      let(:segment) do
        create(:thinking_segment, content: "One two three.", token_count: 240, generation_ms: 4000)
      end

      # The order is the point. The word count climbs while the model reasons,
      # anchored to the right edge of the row; a rate appended *after* it would
      # appear at the end and shove a number the eye was following sideways.
      it "puts the rate ahead of the word count, leaving it where it was" do
        expect(tally).to end_with("60 tok/s · 3#{nbsp}words")
      end
    end
  end
end
