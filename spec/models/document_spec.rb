require "rails_helper"

RSpec.describe Document do
  describe ".unsorted" do
    subject(:unsorted) { described_class.unsorted }

    let(:document) { create(:document) }

    context "when the document is in no collection" do
      before { document }

      it "is included" do
        expect(unsorted).to include(document)
      end
    end

    context "when the document has an active membership" do
      before { create(:collection_membership, document:, collection: create(:collection), source: "manual") }

      it "is excluded" do
        expect(unsorted).not_to include(document)
      end
    end

    context "when the document's only membership is removed" do
      before { create(:collection_membership, :removed, document:, collection: create(:collection)) }

      it "is included (a tombstoned membership doesn't sort it)" do
        expect(unsorted).to include(document)
      end
    end

    context "when the document itself is removed" do
      let(:document) { create(:document, status: "removed") }

      before { document }

      it "is excluded (gone from its source, not merely unsorted)" do
        expect(unsorted).not_to include(document)
      end
    end
  end
end
