require 'rails_helper'

RSpec.describe Document do
  subject { described_class.new(state: :created, link:, file:, filename:, chunking_profile:, collection:, user:) }

  let(:collection) { create(:collection) }
  let(:user) { create(:user) }
  let(:file) { nil }
  let(:filename) { nil }
  let(:link) { nil }
  let(:chunking_method) { :basic }
  let(:chunking_profile) { create(:chunking_profile, method: chunking_method, size: 800) }

  describe "when document has a web link" do
    let(:link) { "https://en.wikipedia.org/wiki/Tabloid_journalism" }

    it "#web? is true" do
      expect(subject.web?).to be true
    end

    it "#file is not attached" do
      expect(subject.file.attached?).to be false
    end

    it "#filename is nil" do
      expect(subject.filename).to be_nil
    end
  end

  describe "when document has a file" do
    let(:file) { fixture_file_upload("gnu_manifesto.md", 'application/html') }
    let(:filename) { "spec/fixtures/files/gnu_manifesto.md" }

    it "#web? is false" do
      expect(subject.web?).to be false
    end

    it "#file is attached" do
      expect(subject.file.attached?).to be true
    end

    it "#filename is present" do
      expect(subject.filename).not_to be_nil
    end
  end
end
