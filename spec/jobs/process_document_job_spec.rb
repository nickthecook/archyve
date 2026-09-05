require "rails_helper"

RSpec.describe ProcessDocumentJob do
  subject(:job) { described_class.new }

  let(:document) { create(:document, :with_file) }
  let(:items) { [Docling::Result::Item.new(text: "Body text.", label: "text", level: nil, page: nil)] }
  let(:docling_result) { instance_double(Docling::Result, items: items) }
  let(:client) { instance_double(Docling::Client, convert: docling_result) }
  let(:vector) { Array.new(Embedding::DIMENSIONS) { 0.1 } }

  before do
    allow(Docling::Client).to receive(:new).and_return(client)
    allow(Embeddings::Embed).to receive(:document).and_return(vector)
  end

  describe "#perform" do
    context "with a valid document" do
      it "marks the document processed" do
        job.perform(document)
        expect(document.reload.status).to eq("processed")
      end

      it "stores the extracted chunks" do
        expect { job.perform(document) }.to change { document.chunks.count }.from(0).to(1)
      end

      it "embeds each chunk with the corpus model" do
        job.perform(document)
        expect(document.chunks.first.embeddings.first.embedding_model).to eq(Embedding::DEFAULT_MODEL)
      end
    end

    context "when the document has no attached file" do
      let(:document) { create(:document) }

      it "raises MissingFile" do
        expect { job.perform(document) }.to raise_error(described_class::MissingFile)
      end

      it "marks the document failed" do
        suppress(described_class::MissingFile) { job.perform(document) }
        expect(document.reload.status).to eq("failed")
      end
    end

    context "when extraction fails" do
      before { allow(client).to receive(:convert).and_raise(Docling::Client::Error) }

      it "re-raises the error" do
        expect { job.perform(document) }.to raise_error(Docling::Client::Error)
      end

      it "marks the document failed" do
        suppress(Docling::Client::Error) { job.perform(document) }
        expect(document.reload.status).to eq("failed")
      end
    end

    context "when reprocessing a document that already has chunks" do
      before { create(:chunk, document: document, position: 0, content: "stale") }

      it "replaces the prior chunks rather than appending" do
        job.perform(document)
        expect(document.chunks.reload.pluck(:content)).to eq(["Body text."])
      end
    end
  end
end
