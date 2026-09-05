require "rails_helper"

RSpec.describe Docling::Result do
  subject(:result) { described_class.new(raw) }

  # A real docling-serve response captured from converting spec/fixtures/files/sample.md.
  let(:raw) { JSON.parse(Rails.root.join("spec/fixtures/files/docling_response.json").read) }

  describe "#status" do
    it "reports success" do
      expect(result.status).to eq("success")
    end
  end

  describe "#title" do
    it "returns the document's title element" do
      expect(result.title).to eq("Archyve Test Document")
    end
  end

  describe "#markdown" do
    it "is nil because we request json only" do
      expect(result.markdown).to be_nil
    end
  end

  describe "#items" do
    let(:items) { result.items }

    it "returns a normalized item per non-empty text element" do
      expect(items.size).to eq(11)
    end

    it "treats the title as a level-0 heading" do
      title = items.first
      expect(title).to have_attributes(label: "title", level: 0, heading?: true)
    end

    it "marks body text as a non-heading" do
      body = items.find { |i| i.label == "text" }
      expect(body.heading?).to be(false)
    end
  end
end
