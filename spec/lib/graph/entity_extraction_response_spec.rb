RSpec.describe Graph::EntityExtractionResponse do
  subject { described_class.new(text) }

  context "when text is an entity" do
    let(:text) do
      ' ("entity" | "Minnie M. Baxter" | "organization" | "Minnie M. Baxter is a boat with shining letters on it.")##'
    end

    it "matches" do
      expect(subject).to be_match
    end

    it "is an entity" do
      expect(subject).to be_entity
    end

    it "is not a relationship" do
      expect(subject).not_to be_relationship
    end

    it "returns match data" do
      expect(subject.to_h).to include(
        type: "entity",
        name: "Minnie M. Baxter",
        subtype: "organization",
        desc: "Minnie M. Baxter is a boat with shining letters on it."
      )
    end
  end

  context "when text is a relationship" do
    let(:text) do
      '("relationship" | "Man" | "Minnie M. Baxter" | "The man is the proud owner of Minnie M. Baxter.")## '
    end

    it "matches" do
      expect(subject).to be_match
    end

    it "is a relationship" do
      expect(subject).to be_relationship
    end

    it "is not an entity" do
      expect(subject).not_to be_entity
    end
  end

  context "when text is neither an entity nor a relationship" do
    let(:text) { "This is not an entity or a relationship." }

    it "doesn't match" do
      expect(subject).not_to be_match
    end

    it "is not an entity" do
      expect(subject).not_to be_entity
    end

    it "is not a relationship" do
      expect(subject).not_to be_relationship
    end
  end
end
