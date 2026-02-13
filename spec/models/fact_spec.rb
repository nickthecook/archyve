require "rails_helper"

RSpec.describe Fact do
  subject(:fact) { create(:fact, :with_file) }

  describe "#parser" do
    it "returns a Parsers::Fact" do
      expect(fact.parser).to be_a(Parsers::Fact)
    end
  end

  describe "chunking" do
    it "produces a single chunk" do
      chunks = fact.parser.chunks
      expect(chunks.length).to eq(1)
      expect(chunks.first.excerpt).to eq("This is a fact.")
    end
  end
end
