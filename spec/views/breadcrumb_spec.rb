require "rails_helper"

RSpec.describe Views::Breadcrumb do
  subject(:component) { described_class.new(*trail) }

  let(:result) { component.call }

  describe "#call" do
    context "with ancestors above the current page" do
      let(:trail) { [["Collections", "/collections"], "Archyve Design"] }

      it "links the ancestors" do
        expect(result).to include(%(<a href="/collections" class="hover:text-muted transition-colors">Collections</a>))
      end

      it "leaves the page you are on as plain text" do
        expect(result).to include(%(<span class="text-muted">Archyve Design</span>))
      end

      it "separates the crumbs" do
        expect(result).to include("›")
      end
    end

    # A link back to the page you are already on is a dead control, so the last
    # crumb never links however it was written.
    context "with a href on the last crumb" do
      let(:trail) { [["Settings", "/settings"], ["People", "/settings/users"]] }

      it "still doesn't link it" do
        expect(result).not_to include(%(href="/settings/users"))
      end
    end

    context "with nothing above the current page" do
      let(:trail) { ["Unsorted"] }

      it "renders no separator" do
        expect(result).not_to include("›")
      end
    end
  end
end
