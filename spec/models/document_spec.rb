require 'rails_helper'

RSpec.describe Document do
  subject { described_class.new(state: :created, link:, file:, filename:, chunking_profile:, collection:, user:, parent:) }

  let(:collection) { create(:collection) }
  let(:user) { create(:user) }
  let(:file) { nil }
  let(:filename) { nil }
  let(:link) { nil }
  let(:chunking_method) { :basic }
  let(:chunking_profile) { create(:chunking_profile, method: chunking_method, size: 800) }
  let(:parent) { nil }

  context "with a web link" do
    let(:link) { "https://en.wikipedia.org/wiki/Tabloid_journalism" }

    it "returns true for #web?" do
      expect(subject.web?).to be true
    end

    it "is not attached" do
      expect(subject.file.attached?).to be false
    end

    it "has no file name" do
      expect(subject.filename).to be_nil
    end

    it "has no content type" do
      expect(subject.file.content_type).to be_nil
    end
  end

  context "with a markdown file" do
    let(:file) { fixture_file_upload("gnu_manifesto.md") }
    let(:filename) { "spec/fixtures/files/gnu_manifesto.md" }

    it "is not a web link" do
      expect(subject.web?).to be false
    end

    it "is attached" do
      expect(subject.file.attached?).to be true
    end

    it "has text content type" do
      expect(subject.content_type).to start_with("text/")
    end

    it "has file name" do
      expect(subject.filename).not_to be_nil
    end
  end

  context "with a JPEG file" do
    let(:filename) { "spec/fixtures/files/avatar.jpg" }
    let(:file) { fixture_file_upload("avatar.jpg") }

    it "is attached" do
      expect(subject.file.attached?).to be true
    end

    it "is an image" do
      expect(subject.image?).to be true
    end
  end

  context "with a PDF file" do
    let(:filename) { "spec/fixtures/files/gnu_manifesto.pdf" }
    let(:file) { fixture_file_upload("gnu_manifesto.pdf") }

    it "is attached" do
      expect(subject.file.attached?).to be true
    end

    it "has content type 'application/pdf" do
      expect(subject.file.content_type).to eq("application/pdf")
    end

    it "is not an image" do
      expect(subject.image?).to be false
    end
  end

  context "with an MP3 file" do
    let(:filename) { "spec/fixtures/files/sample-3s.mp3" }
    let(:file) { fixture_file_upload("sample-3s.mp3") }

    it "is attached" do
      expect(subject.file.attached?).to be true
    end

    it "is audio" do
      expect(subject.audio?).to be true
    end
  end

  context "with a parent document" do
    let(:parent) { create(:document, parent: nil) }

    it "has parent" do
      expect(subject.parent).not_to be_nil
    end

    it "has no grand parent" do
      expect(parent.parent).to be_nil
    end

    it "has parent as original document" do
      expect(subject.original_document).to eq(parent)
    end

    it "is not an original document" do
      expect(subject.original_document?).to be false
    end
  end

  context "with a grandparent document" do
    let(:grandparent) { create(:document) }
    let(:parent) { create(:document, parent: grandparent) }

    it "has parent" do
      expect(subject.parent).not_to be_nil
    end

    it "has grand parent" do
      expect(parent.parent).not_to be_nil
    end

    it "has grandparent as original document" do
      expect(subject.original_document).to eq(grandparent)
    end
  end
end
