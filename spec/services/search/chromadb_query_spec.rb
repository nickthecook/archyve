RSpec.describe Search::ChromadbQuery do
  subject { described_class.new(collection, query) }

  let(:collection) { create(:collection) }
  let(:query) { "How often does my fireplace need to be cleaned?" }
  let(:chroma_double) { instance_double(Chromadb::Client, query: results, collection_id: "1234") }
  let(:results) { JSON.parse(File.read(file_fixture("chromadb/chroma_query_response.json"))) }

  before do
    allow(Chromadb::Client).to receive(:new).and_return(chroma_double)

    create(:chunk, vector_id: "ede2c4ab-77a1-4e26-9575-3cfadc774ce8")
    create(:chunk, vector_id: "62222c27-b496-4722-bc5a-9aa8e8495ed7")
    create(:chunk, vector_id: "63b79d0b-482f-483a-8744-2f8f771b7fbb")
    create(:chunk, vector_id: "d252939a-9f57-45e7-8265-78803eed786b")
    create(:chunk, vector_id: "2ce77549-d65f-4a54-bc4b-45a8a17b49de")
  end

  describe "#results" do
    it "returns the correct number of results" do
      expect(subject.results.count).to eq(5)
    end

    it "returns SearchHits" do
      expect(subject.results).to all be_a(Search::SearchHit)
    end

    it "sets the distance for each hit" do
      expect(subject.results.map(&:distance)).to eq([200.0, 300.0, 400.0, 500.0, 600.0])
    end

    it "sets the previous_distance for each hit" do
      expect(subject.results.map(&:previous_distance)).to eq([nil, 200.0, 300.0, 400.0, 500.0])
    end
  end
end
