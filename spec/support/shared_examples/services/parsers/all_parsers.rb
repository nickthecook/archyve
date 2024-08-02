RSpec.shared_examples "all parsers" do
  # Requires
  # - `subject` to be instance of a parser

  describe "#chunks" do
    it "succeeds" do
      expect(subject.chunks).to be_a(Enumerable)
    end
  end
end
