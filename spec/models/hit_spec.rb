require "rails_helper"

RSpec.describe Hit do
  # A citation is only worth rendering if it leads to the passage it cites, and
  # a hit outlives the chunk it recorded — so this has to degrade, not break.
  describe "#href" do
    subject(:href) { hit.href }

    let(:document) { create(:document) }

    # A fixed-set agent can cite a document its user may not open.
    context "when the conversation's owner can't open the document" do
      let(:hit) { create(:hit, chunk: create(:chunk, document:), document:) }

      it { expect(href).to be_nil }
    end

    context "when the chunk it recorded is still there" do
      let(:chunk) { create(:chunk, document:) }
      let(:hit) { create(:hit, :reachable, chunk:, document:) }

      it "points at the chunk within the document" do
        expect(href).to eq("/documents/#{document.id}#chunk_#{chunk.id}")
      end

      it "matches the id documents#show gives that chunk's card" do
        expect(href).to end_with("##{chunk.anchor}")
      end
    end

    # Reingesting a document destroys its chunks and makes new ones. Last
    # week's chat still cites the document; it just can't name the passage.
    context "when the chunk is gone" do
      let(:hit) { create(:hit, :reachable, chunk: nil, document:) }

      it "points at the document" do
        expect(href).to eq("/documents/#{document.id}")
      end
    end

    context "when the document is gone too" do
      let(:hit) { create(:hit, chunk: nil, document: nil) }

      it "leads nowhere" do
        expect(href).to be_nil
      end

      it "agrees with followable?" do
        expect(hit).not_to be_followable
      end
    end
  end
end
