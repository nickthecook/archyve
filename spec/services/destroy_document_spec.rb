RSpec.describe DestroyDocument do
  subject { described_class.new(doc) }

  let(:collection) { create(:collection) }
  let(:user) { create(:user) }
  let(:file) { fixture_file_upload("gnu_manifesto.md") }
  let(:filename) { "spec/fixtures/files/gnu_manifesto.md" }
  let(:link) { nil }
  let(:chunking_method) { :basic }
  let(:chunking_profile) { create(:chunking_profile, method: chunking_method, size: 800) }
  let!(:doc) { create(:document, state: :created, link:, file:, filename:, chunking_profile:, collection:, user:) }

  describe "#execute" do
    context "when document has children" do
      before do
        create(:document, parent: doc)
      end

      it "destroys both documents document" do
        expect { subject.execute }.to change(Document, :count).by(-2)
      end
    end

    context "with childless document" do
      it "destroys document" do
        expect { subject.execute }.to change(Document, :count).by(-1)
      end
    end
  end
end
