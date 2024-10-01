RSpec.describe FetchWebDocument do
  subject { described_class.new(document) }

  let(:document) { create(:document, link:, state:) }
  let(:link) { "http://example.com/about.html" }
  let(:state) { "created" }
  let(:link_contents) { "about" }

  before do
    allow(HTTParty).to receive(:get).and_return(link_contents)
  end

  describe "#execute" do
    it "fetches the document content" do
      expect { subject.execute }.to change(document, :contents).from(nil).to("about")
    end

    it "attaches the content to the document" do
      expect { subject.execute }.to change { document.file.attached? }.from(false).to(true)
    end

    it "sets the content type" do
      subject.execute
      expect(document.file.content_type).to eq("text/html")
    end

    context "when document is not in created state" do
      let(:state) { "errored" }
      let(:resetter) { instance_double(ResetDocument, execute: nil) }

      before do
        allow(ResetDocument).to receive(:new).and_return(resetter)
      end

      it "resets the document" do
        subject.execute
        expect(resetter).to have_received(:execute)
      end
    end
  end
end
