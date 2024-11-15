require 'rails_helper'

RSpec.describe ConvertDocumentJob do
  subject { described_class.new }

  let(:collection) { create(:collection) }
  let(:user) { create(:user) }
  let(:file) { nil }
  let(:filename) { nil }
  let(:link) { nil }
  let(:chunking_method) { :basic }
  let(:chunking_profile) { create(:chunking_profile, method: chunking_method, size: 800) }
  let(:doc) { create(:document, state: :created, link:, file:, filename:, chunking_profile:, collection:, user:) }

  describe "#perform" do
    context "with a PDF document" do
      let(:filename) { "spec/fixtures/files/gnu_manifesto.pdf" }
      let(:file) { fixture_file_upload("gnu_manifesto.pdf") }

      before do
        allow(Mediator).to receive("ingest")
      end

      it "calls Mediator after conversion" do
        subject.perform(doc.id)

        expect(Mediator).to have_received("ingest").with(subject.new_doc)
      end

      it "produces a new document" do
        subject.perform(doc.id)

        expect(subject.new_doc).not_to be_nil
      end
    end
  end
end
