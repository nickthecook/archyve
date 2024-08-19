RSpec.describe Graph::ExtractDocumentEntities do
  subject { described_class.new(document) }

  include_context "with default models"

  let(:document) { create(:document, chunks:) }
  let(:chunks) { create_list(:chunk, 3) }

  let(:extractor) { instance_double(Graph::EntityExtractor, extract: nil) }

  before do
    allow(Graph::EntityExtractor).to receive(:new).and_return(extractor)
  end

  describe "#execute" do
    it "calls EntityExtractor on each chunk" do
      subject.execute
      # TODO: there is a way to do this with one `expect`, passing `with` a list of the consecutive chunks
      expect(extractor).to have_received(:extract).with(document.chunks[0])
      expect(extractor).to have_received(:extract).with(document.chunks[1])
      expect(extractor).to have_received(:extract).with(document.chunks[2])
    end

    it "updates the document process step" do
      expect { subject.execute }.to change { document.reload.process_step }.from(nil).to(3)
    end

    it "updates the document process steps" do
      expect { subject }.to change(document, :process_steps).from(nil).to(3)
    end
  end
end
