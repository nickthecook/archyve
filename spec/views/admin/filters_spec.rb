require "rails_helper"

RSpec.describe Views::Admin::Filters do
  subject(:component) { described_class.new(action: "/settings/api_calls", facets:) }

  let(:result) { component.call }
  let(:selected) { nil }
  let(:facets) do
    [Views::Admin::Facet.new(label: "Kind", param: "kind", options: ["chat", "discovery"], selected:)]
  end

  describe "#call" do
    it "submits to the list it filters, as a GET so the result is a URL" do
      expect(result).to include(%(action="/settings/api_calls"), %(method="get"))
    end

    it "offers every value, and no choice as the default" do
      expect(result).to include(">Any kind<", ">chat<", ">discovery<")
    end

    context "with nothing selected" do
      it "offers no Clear" do
        expect(result).not_to include("Clear")
      end
    end

    context "with a value selected" do
      let(:selected) { "chat" }

      it "marks it" do
        expect(result).to include(%(<option value="chat" selected>))
      end

      it "offers a way back to the unfiltered list" do
        expect(result).to include(%(<a href="/settings/api_calls"), "Clear")
      end
    end

    context "with a facet that has nothing to offer" do
      let(:facets) { [Views::Admin::Facet.new(label: "Host", param: "host", options: [])] }

      it "renders nothing rather than an empty control" do
        expect(result).to eq("")
      end
    end

    context "with an option that reads badly as its own label" do
      let(:facets) do
        [Views::Admin::Facet.new(label: "Outcome", param: "outcome", options: [["4", "timed out"]])]
      end

      it "shows the label and submits the value" do
        expect(result).to include(%(<option value="4">timed out</option>))
      end
    end
  end
end
