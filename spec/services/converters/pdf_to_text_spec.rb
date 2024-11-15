RSpec.describe Converters::PdfToText do
  subject { described_class.new(doc) }

  let(:collection) { create(:collection) }
  let(:user) { create(:user) }
  let(:filename) { "spec/fixtures/files/gnu_manifesto.pdf" }
  let(:file) { fixture_file_upload("gnu_manifesto.pdf") }
  let(:link) { nil }
  let(:chunking_method) { :basic }
  let(:chunking_profile) { create(:chunking_profile, method: chunking_method, size: 800) }
  let(:doc) { create(:document, state: :created, link:, file:, filename:, chunking_profile:, collection:, user:) }

  describe "#ready?" do
    it "succeeds" do
      expect(subject.ready?).to be true
    end
  end

  describe "#convert" do
    it "succeeds with new document" do
      expect(subject.convert).to be_a(Document)
    end

    it "sets status to DONE" do
      subject.convert
      expect(subject.done?).to be true
    end

    it "returns nil if called twice" do
      subject.convert
      expect(subject.convert).to be_nil
    end

    it "returns new document with text format" do
      new_doc = subject.convert
      expect(new_doc.content_type).to eq("text/plain")
    end

    it "returns new document with text extension" do
      new_doc = subject.convert
      expect(new_doc.filename).to end_with(".txt")
    end
  end
end
