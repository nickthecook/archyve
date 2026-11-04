require "rails_helper"

RSpec.describe Views::Conversations::Reading do
  describe "#call" do
    subject(:reading) { described_class.new(segment:) }

    let(:result) { reading.call }
    let(:segment) { create(:reading_segment, :reachable) }
    let(:document) { create(:document, title: "SHS-2920 manual") }

    context "when a document was read" do
      let(:chunk) { create(:chunk, document:, position: 9) }

      before { create(:hit, :read, segment:, chunk:, document:, handle: 9) }

      it "names what was read" do
        expect(result).to include("Read Security Handbook")
      end

      it "says which part of it, out of how much" do
        expect(result).to include("chunks 10–14 of 47")
      end

      it "makes the card a link to the passage" do
        expect(result).to include(%(href="/documents/#{document.id}#chunk_#{chunk.id}"))
      end

      # Nothing ranked these chunks — the model asked for them by position —
      # so a percentage would be a relevance reading nobody took.
      it "shows where the chunk sits" do
        expect(result).to include("#10")
      end

      it "shows no similarity" do
        expect(result).not_to include("%")
      end
    end

    # Nothing is recorded until the read returns, so an absent reading is one
    # still running rather than one that read nothing.
    context "while the read is still running" do
      let(:segment) { create(:reading_segment, reading: nil) }

      it "says so rather than showing an empty document" do
        expect(result).to include("Reading a document…")
      end
    end

    # The tool refuses an unreadable id exactly as it refuses one that never
    # existed; a panel that named the document would undo that.
    context "when the read was refused" do
      let(:segment) { create(:reading_segment, reading: { "refusal" => "not_found" }) }

      it "says the read failed" do
        expect(result).to include("read that document")
      end

      it "names no document" do
        expect(result).not_to include("Security Handbook")
      end
    end

    context "when the document had not been processed" do
      let(:segment) do
        create(:reading_segment, reading: { "refusal" => "not_processed", "title" => "Security Handbook" })
      end

      # Distinct from a missing document: text is coming, just not yet.
      it "says the text isn't there yet" do
        expect(result).to include("finished processing")
      end
    end
  end
end
