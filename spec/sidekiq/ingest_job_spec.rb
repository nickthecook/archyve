require 'rails_helper'
RSpec.describe IngestJob, type: :job do
  let(:ingestor_double) { instance_double(TheIngestor) }
  let(:document) { create(:document) }
  let(:args) { document.id }

  before do
    allow(TheIngestor).to receive(:new).and_return(ingestor_double)
    allow(ingestor_double).to receive(:execute)
  end

  describe "#perform" do
    it "creates The Ingestor with the correct document" do
      subject.perform(args)
      expect(TheIngestor).to have_received(:new).with(document)
    end

    it "runs The Ingestor" do
      subject.perform(args)
      expect(ingestor_double).to have_received(:execute)
    end
  end
end
