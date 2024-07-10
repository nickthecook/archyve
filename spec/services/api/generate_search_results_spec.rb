RSpec.describe Api::GenerateSearchResults do
  subject { described_class.new(collections, base_url:, browser_base_url:, num_results:, traceable:) }

  let(:collections) { create_list(:collection, 2) }
  let(:base_url) { 'http://example.com' }
  let(:browser_base_url) { 'https://example.com' }
  let(:num_results) { 2 }
  let(:traceable) { nil }

  let(:searchn_double) { instance_double(Search::SearchN, search: hits) }
  let(:chunks) { create_list(:chunk, 5) }
  let(:hits) do
    [
      Search::SearchHit.new(chunks[0], 200.0),
      Search::SearchHit.new(chunks[1], 220.0),
      Search::SearchHit.new(chunks[2], 400.0),
      Search::SearchHit.new(chunks[3], 450.0),
      Search::SearchHit.new(chunks[4], 500.0),
    ]
  end

  before do
    allow(Search::SearchN).to receive(:new).and_return(searchn_double)

    hits.each { |hit| hit.relevant = true }
  end

  describe "#search" do
    let(:query) { 'test' }

    it "searches the given collections" do
      subject.search(query)
      expect(searchn_double).to have_received(:search).with(query)
    end

    it "returns an array of search result hashes" do
      expect(subject.search(query)).to eq([
        {
          id: chunks.first.id,
          document: chunks.first.content,
          metadata: "",
          distance: hits.first.distance,
          vector_id: chunks.first.vector_id,
          url: "http://example.com/v1/chunks/#{chunks.first.id}",
          browser_url: "https://example.com/collections/#{chunks.first.document.collection.id}/documents/#{chunks.first.document.id}/chunks/#{chunks.first.id}",
          relevant: true,
        },
        {
          id: chunks.second.id,
          document: chunks.second.content,
          metadata: "",
          distance: hits.second.distance,
          vector_id: chunks.second.vector_id,
          url: "http://example.com/v1/chunks/#{chunks.second.id}",
          browser_url: "https://example.com/collections/#{chunks.second.document.collection.id}/documents/#{chunks.second.document.id}/chunks/#{chunks.second.id}",
          relevant: true,
        },
      ])
    end
  end
end
