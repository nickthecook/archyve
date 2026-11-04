require "rails_helper"

RSpec.describe Tools::Admin::DocumentProcessing do
  subject(:tool) { described_class.new }

  describe "#execute" do
    let(:result) { tool.execute }

    context "with no documents" do
      it { expect(result[:by_status]).to eq("no documents") }
    end

    context "with documents in several states" do
      before do
        create_list(:document, 2, status: "processed")
        create(:document, status: "failed", title: "Broken.pdf", outcome_stage: "extract",
          outcome_kind: "unreachable", outcome_detail: "docling refused")
        create(:document, status: "processing", title: "Slow.pdf").update_column(:updated_at, 2.hours.ago)
        create(:document, status: "processing", title: "Fresh.pdf")
      end

      it "counts them by status" do
        expect(result[:by_status]).to include("processed 2", "failed 1", "processing 2")
      end

      it "says where and why a document failed" do
        expect(result[:failed].first).to include(title: "Broken.pdf", stage: "extract", detail: "docling refused")
      end

      it "lists only documents that have been processing too long" do
        expect(result[:stuck].map { it[:title] }).to eq(["Slow.pdf"])
      end
    end
  end
end
