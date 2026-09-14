require "rails_helper"

RSpec.describe Document do
  # What every live region asks to decide whether to keep polling.
  describe "#settled?" do
    subject { create(:document, status:).settled? }

    context "when pending" do
      let(:status) { "pending" }

      it { is_expected.to be(false) }
    end

    context "when processing" do
      let(:status) { "processing" }

      it { is_expected.to be(false) }
    end

    context "when processed" do
      let(:status) { "processed" }

      it { is_expected.to be(true) }
    end

    # Failure is an outcome, not work in progress: nothing will move it without
    # a re-upload, so watching it is a busy loop.
    context "when failed" do
      let(:status) { "failed" }

      it { is_expected.to be(true) }
    end

    context "when removed" do
      let(:status) { "removed" }

      it { is_expected.to be(true) }
    end
  end

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
      before { create(:collection_membership, document:, collection: create(:collection), origin: "manual") }

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
