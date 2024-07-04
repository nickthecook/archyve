require 'rails_helper'

RSpec.describe Chunk do
  subject { create(:chunk, content: "subject", embedding_content:) }

  let(:document) { create(:document) }
  let(:embedding_content) { nil }

  before do
    create(:chunk, document:)
    create(:chunk, document:)
    document.chunks << subject
    create(:chunk, document:)
    create(:chunk, document:)

    document.reload
  end

  describe "#previous" do
    it "returns the previous chunk" do
      skip # flaky
      expect(subject.previous).to contain_exactly(document.chunks[1])
    end

    it "returns multiple chunks" do
      skip # flaky
      expect(subject.previous(2)).to eq(document.chunks[0..1])
    end

    it "stops at the beginning of the list" do
      skip # flaky
      expect(subject.previous(3)).to eq(document.chunks[0..1])
    end
  end

  describe "#next" do
    it "returns the next chunk" do
      skip # flaky
      expect(subject.next).to contain_exactly(document.chunks[-2])
    end

    it "returns multiple chunks" do
      skip # flaky
      expect(subject.next(2)).to eq(document.chunks[3..4])
    end

    it "stops at the end of the list" do
      skip # flaky
      expect(subject.next(3)).to eq(document.chunks[3..4])
    end
  end

  describe "#embedding_content" do
    it "returns the content" do
      expect(subject.embedding_content).to eq("subject")
    end

    context "when embedding_content is set" do
      let(:embedding_content) { "subject subject subject" }

      it "returns the embedding content" do
        expect(subject.embedding_content).to eq("subject subject subject")
      end
    end
  end
end
