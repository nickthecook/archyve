require 'rails_helper'

RSpec.describe FetchWebDocumentJob do
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
    context "with document with web link" do
      let(:link) { "https://en.wikipedia.org/wiki/Tabloid_journalism" }

      before do
        allow(Mediator).to receive("ingest")
      end

      it "fetches web page" do
        subject.perform(doc.id)

        expect(Mediator).to have_received("ingest").with(doc)
      end
    end
  end
end
