require "rails_helper"

RSpec.describe Source, "OCR" do
  subject(:source) { create(:folder_source) }

  describe "#ocr?" do
    context "when nobody has chosen" do
      it "matches docling's own default, so an existing archive keeps extracting scans" do
        expect(source.ocr?).to be(true)
      end
    end

    context "when it has been turned off" do
      before { source.update!(ocr: false) }

      it "is off" do
        expect(source.reload.ocr?).to be(false)
      end
    end

    # What a checkbox actually submits.
    context "when set from form values" do
      it "reads \"0\" as off" do
        source.update!(ocr: "0")
        expect(source.reload.ocr?).to be(false)
      end

      it "reads \"1\" as on" do
        source.update!(ocr: "1")
        expect(source.reload.ocr?).to be(true)
      end

      # Stored cast rather than raw: "0" in jsonb is truthy to everything that
      # reads the column without going through this model.
      it "stores a real boolean" do
        source.update!(ocr: "0")
        expect(source.reload.config["ocr"]).to be(false)
      end
    end
  end
end
