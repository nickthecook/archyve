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

        expect(Mediator).to have_received("ingest").with(Document.last)
      end

      it "creates new document conversion" do
        doc.save # to overcome lazy let(:doc) affecting count
        expect { subject.perform(doc.id) }.to change(Document, :count).by(1)
      end
    end
  end
end
