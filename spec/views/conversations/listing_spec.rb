require "rails_helper"

RSpec.describe Views::Conversations::Listing do
  describe "#call" do
    subject(:listing) { described_class.new(segment:) }

    let(:result) { listing.call }
    let(:segment) { create(:listing_segment) }

    context "when collections were listed" do
      it "says what it did" do
        expect(result).to include("Listed the collections in this chat")
      end

      it "counts them" do
        expect(result).to include("2 collections")
      end

      it "says where each one's documents come from" do
        expect(result).to include("Fed by Wiki")
      end

      it "says so when nothing feeds one" do
        expect(result).to include("No source feeds this collection")
      end

      it "makes each row a way into the collection" do
        expect(result).to include(%(href="/collections/security-handbook"))
      end
    end

    context "when documents were listed" do
      let(:segment) { create(:listing_segment, :documents) }

      it "names the collection it listed" do
        expect(result).to include("Listed Security Handbook")
      end

      it "says which part of it, out of how much" do
        expect(result).to include("1–2 of 9 documents")
      end

      it "makes each row a way into the document" do
        expect(result).to include(%(href="/documents/41"))
      end

      it "says how much there is to read" do
        expect(result).to include("14 chunks")
      end

      # Zero chunks reads as an empty document rather than one that isn't ready.
      it "says a document without chunks hasn't been processed" do
        expect(result).to include("not processed")
      end
    end

    # Nothing is recorded until the listing returns, so an absent listing is one
    # still running rather than one that listed nothing.
    context "while it is still running" do
      let(:segment) { create(:listing_segment, listing: nil) }

      it "says it is looking" do
        expect(result).to include("Looking through the archive")
      end

      it "counts nothing yet" do
        expect(result).not_to include("collections")
      end
    end

    # Vaguer than the reason, deliberately: a slug outside the scope is refused
    # exactly as one that never existed — see Tools::ListDocuments.
    context "when the listing was refused" do
      let(:segment) { create(:listing_segment, :refused) }

      it "says it couldn't list it" do
        expect(result).to include("list that collection")
      end

      it "says no more than that it is out of scope" do
        expect(result).to include("scope.")
      end
    end
  end
end
