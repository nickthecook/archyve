RSpec.describe TheIngestor do
  subject { described_class.new(document) }

  # TODO: when chunking_profile#method is renamed, we can let the factory create the chunking_profile
  let(:chunking_profile) { create(:chunking_profile, method: "bytes") }
  let(:document) { create(:document, state: :created, file:, chunking_profile:) }
  let(:file) { fixture_file_upload("small_doc.md", 'application/*') }
  let(:embedder_double) { instance_double(Embedder, embed: [2.0, 1.1, 0.2]) }
  let(:chromadb_double) do
    instance_double(
      Chromadb::Client,
      add_documents: [123, 124, 125],
      create_collection: { "id" => 122 },
      collection_id:
    )
  end
  let(:collection_id) { nil }

  before do
    create(:model_server)
    create(:model_config)

    allow(Embedder).to receive(:new).and_return(embedder_double)
    allow(Chromadb::Client).to receive(:new).and_return(chromadb_double)
  end

  describe "#ingest" do
    let(:result) { subject.ingest }

    it "sets the document state to 'embedded'" do
      expect { result }.to change(document, :state).from("created").to("embedded")
    end

    it "ensures that the chromadb collection exists" do
      result
      expect(chromadb_double).to have_received(:create_collection).with(
        document.collection.slug,
        { creator: "archyve" }
      )
    end

    it "chunks the document" do
      expect { result }.to change { document.chunks.reload.present? }.from(false).to(true)
    end

    context "when chromadb collection exists" do
      let(:collection_id) { 122 }

      it "does not create the collection" do
        result
        expect(chromadb_double).not_to have_received(:create_collection)
      end
    end

    context "when an error occurs while embedding" do
      before do
        allow(embedder_double).to receive(:embed).and_raise(StandardError.new("error"))
      end

      it "raises the error" do
        expect { result }.to raise_error(StandardError, "error")
      end

      it "sets the document state to 'errored'" do
        expect do
          result
        rescue StandardError
          # this is fine 🔥🪑🐕☕🔥
        end.to change(document, :state).from("created").to("errored")
      end
    end
  end
end
