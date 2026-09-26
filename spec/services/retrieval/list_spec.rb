require "rails_helper"

RSpec.describe Retrieval::List do
  subject(:list) { described_class.new(corpus:) }

  let(:corpus) { Retrieval::Corpus.new(user:, scope:) }
  let(:user) { create(:user) }
  let(:scope) { nil }

  let(:source) { create(:source, name: "Wiki") }
  let(:handbook) { create(:collection, name: "Security Handbook") }
  let(:document) { create(:document, title: "Credential rotation", source:) }

  before do
    create(:collection_membership, collection: handbook, document:, origin: "manual")
    create(:collection_user, collection: handbook, user:)
  end

  describe "#collections" do
    it "names each collection by the slug the tools address it with" do
      expect(list.collections.entries.map { it["slug"] }).to eq([handbook.slug])
    end

    it "counts what is in it" do
      expect(list.collections.entries.first["documents"]).to eq(1)
    end

    # Provenance is half the point: no amount of searching answers "where do
    # these documents come from?".
    context "when a source feeds the collection" do
      before { handbook.sources << source }

      it "names the source" do
        expect(list.collections.entries.first["sources"]).to eq(["Wiki"])
      end
    end

    # "Ops" versus "Platform" is a coin flip; the description is what lets a
    # model tell them apart.
    context "when the collection has been described" do
      before { handbook.update!(description: "Security policy, on-call and incident review.") }

      it "hands the description to the model" do
        expect(list.collections.entries.first["description"]).to eq("Security policy, on-call and incident review.")
      end
    end

    context "when it has not been described" do
      it "carries no description key, rather than an empty one" do
        expect(list.collections.entries.first).not_to have_key("description")
      end
    end

    context "when a collection is one they hold no grant on" do
      before { create(:collection, name: "Payroll") }

      it "leaves it out" do
        expect(list.collections.entries.map { it["name"] }).not_to include("Payroll")
      end
    end

    # The scope is the conversation's corpus, and listing past it has the model
    # describing documents this chat cannot draw on.
    context "when the chat is scoped to one collection" do
      let(:user) { create(:user, role: :admin) }
      let(:scope) { Retrieval::Scope.from_params({ c: [handbook.slug] }, user:) }

      before { create(:collection, name: "Runbooks") }

      it "lists only the collection in scope, even for an admin" do
        expect(list.collections.entries.map { it["name"] }).to eq(["Security Handbook"])
      end
    end

    # A chat pinned to one document still reaches it through a collection, and
    # "which collection is this from?" should have an answer.
    context "when the chat is scoped to one document" do
      let(:user) { create(:user, role: :admin) }
      let(:scope) { Retrieval::Scope.from_params({ doc: document.id }, user:) }

      it "names the collections that document is filed in" do
        expect(list.collections.entries.map { it["name"] }).to eq(["Security Handbook"])
      end

      it "counts only what this chat can draw on" do
        create(:collection_membership, collection: handbook, document: create(:document), origin: "manual")
        expect(list.collections.entries.first["documents"]).to eq(1)
      end
    end
  end

  describe "#documents" do
    subject(:listing) { list.documents(handbook.slug) }

    before { 3.times { |position| create(:chunk, document:, position:) } }

    it "names the document and the id read_document takes" do
      expect(listing.entries).to contain_exactly(
        { "id" => document.id, "title" => "Credential rotation", "source" => "Wiki", "chunks" => 3 }
      )
    end

    it "says which collection was listed" do
      expect(listing.title).to eq("Security Handbook")
    end

    context "when the collection holds more than a page" do
      before { 30.times { create(:collection_membership, collection: handbook, document: create(:document), origin: "manual") } }

      it "returns one page" do
        expect(listing.entries.size).to eq(described_class::MAX_DOCUMENTS)
      end

      it "says how many there are in all, so the model knows to ask again" do
        expect(listing.total).to eq(31)
      end

      it "pages from where it was asked to" do
        expect(list.documents(handbook.slug, from: 26).from).to eq(26)
      end

      it "takes a smaller page when asked for one" do
        expect(list.documents(handbook.slug, limit: 2).entries.size).to eq(2)
      end

      # Models send strings, floats and nulls where the schema says integer.
      it "survives a page size it was never meant to be given" do
        expect(list.documents(handbook.slug, from: "2", limit: 500).entries.size)
          .to eq(described_class::MAX_DOCUMENTS)
      end
    end

    context "when the page starts past the end" do
      it "comes back empty rather than wrapping round" do
        expect(list.documents(handbook.slug, from: 99)).to be_overshot
      end
    end

    context "when the collection is empty" do
      let(:empty) { create(:collection, name: "Runbooks") }

      before { create(:collection_user, collection: empty, user:) }

      it "is empty without having overshot anything" do
        expect(list.documents(empty.slug)).to have_attributes(empty?: true, overshot?: false)
      end
    end

    # Naming is not access: the slug narrows a relation it cannot widen.
    context "when the slug names a collection they hold no grant on" do
      let(:other) { create(:collection, name: "Payroll") }

      it "refuses it exactly as it refuses one that never existed" do
        expect(list.documents(other.slug)).to eq(list.documents("no-such-collection"))
      end
    end

    context "when the chat is scoped to one document" do
      let(:user) { create(:user, role: :admin) }
      let(:scope) { Retrieval::Scope.from_params({ doc: document.id }, user:) }

      before { create(:collection_membership, collection: handbook, document: create(:document, title: "Bastion"), origin: "manual") }

      it "lists only what this chat can draw on" do
        expect(listing.entries.map { it["title"] }).to eq(["Credential rotation"])
      end
    end
  end
end
