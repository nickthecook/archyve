RSpec.describe Search::Filters::DistanceRatio do
  subject { described_class.new(hits) }

  let(:chunks) { create_list(:chunk, 5) }
  let(:hits) do
    [
      Search::SearchHit.new(chunks[0], 200.0),
      Search::SearchHit.new(chunks[1], 220.0, 200.0),
      Search::SearchHit.new(chunks[2], 400.0, 220.0),
      Search::SearchHit.new(chunks[3], 450.0, 400.0),
      Search::SearchHit.new(chunks[4], 500.0, 450.0),
    ]
  end

  describe "#filtered" do
    it "returns hits with a distance ratio lower than the threshold" do
      expect(subject.filtered).to eq([hits[0], hits[1]])
    end
  end

  describe "relevance setting" do
    it "sets the relevance on search hits" do
      subject
      expect(hits.map(&:relevant)).to eq([true, true, false, false, false])
    end
  end
end
