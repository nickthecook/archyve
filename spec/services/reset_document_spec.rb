RSpec.describe ResetDocument do
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
      let(:child) { create(:document, parent: doc) }

      it "destroys only child document" do
        child
        expect { subject.execute }.to change(Document, :count).by(-1)
      end
    end

    context "with childless document" do
      it "destroys nothing" do
        expect { subject.execute }.not_to change(Document, :count)
      end
    end
  end
end
