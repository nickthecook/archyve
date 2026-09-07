require "rails_helper"

# The download branch needs route helpers, so it is covered where the component
# really renders — see spec/requests/search_spec.rb.
RSpec.describe Views::Documents::Access do
  subject(:component) { described_class.new(document:) }

  let(:result) { component.call }

  # Which affordance appears is decided by the source, never by the reader.
  context "when the source can produce links the reader's browser can follow" do
    let(:source) do
      instance_double(
        Source,
        user_accessible_links?: true,
        document_url: "https://wiki.example/books/handbook",
        type_label: "Bookstack"
      )
    end
    let(:document) { instance_double(Document, source:) }

    it "links out to the source" do
      expect(result).to include("https://wiki.example/books/handbook")
    end

    it "names the source, so the reader knows where they are going" do
      expect(result).to include("Open in Bookstack")
    end

    it "does not offer a download" do
      expect(result).not_to include("Download")
    end
  end

  context "when the source cannot and no file was attached" do
    let(:document) { create(:document) }

    it "says the document is unavailable rather than offering a dead link" do
      expect(result).to include("Unavailable")
    end
  end
end
