require "rails_helper"

RSpec.describe Views::ScopeChip do
  subject(:component) { described_class.new(label: "Handbook", **options) }

  let(:options) { {} }
  let(:result) { component.call }

  describe "#call" do
    it "names the scope" do
      expect(result).to include("Handbook")
    end

    context "when searching" do
      it "lights the dot" do
        expect(result).to include("bg-accent")
      end
    end

    context "when nothing is searched" do
      let(:options) { { searching: false } }

      it "dims the dot" do
        expect(result).to include("bg-line-2")
        expect(result).not_to include("bg-accent")
      end
    end

    context "with a title" do
      let(:options) { { title: "Search targets this collection" } }

      it "explains itself on hover" do
        expect(result).to include(%(title="Search targets this collection"))
      end
    end
  end
end
