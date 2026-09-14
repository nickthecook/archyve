require "rails_helper"

RSpec.describe Document, "OCR" do
  let(:source) { create(:folder_source) }
  let(:document) { create(:document, source:, ocr: choice) }

  describe "#ocr?" do
    # The connector case: no answer of its own, so the source's answer applies
    # — change the source, reprocess, and its documents follow.
    context "when the document has no answer of its own" do
      let(:choice) { nil }

      it "follows a source with OCR on" do
        expect(document.ocr?).to be(true)
      end

      it "follows a source with OCR off" do
        source.update!(ocr: false)
        expect(document.ocr?).to be(false)
      end
    end

    # The upload case: someone was asked about this file, and their answer has
    # to survive a reprocess long after the source's default moved.
    context "when the uploader answered for this file" do
      let(:choice) { false }

      it "keeps their answer even where the source disagrees" do
        source.update!(ocr: true)
        expect(document.ocr?).to be(false)
      end
    end
  end
end
