require "rails_helper"

RSpec.describe Tools::ListDocuments do
  describe "#execute" do
    subject(:tool) { described_class.new(corpus:, handles:, observer:) }

    let(:result) { tool.execute(collection: collection.slug) }

    let(:user) { create(:user) }
    let(:scope) { nil }
    let(:corpus) { Retrieval::Corpus.new(user:, scope:) }
    let(:handles) { Retrieval::Handles.new }
    let(:observer) { nil }

    let(:collection) { create(:collection, name: "Security Handbook") }
    let(:document) { create(:document, title: "Credential rotation", source: create(:source, name: "Wiki")) }

    before do
      3.times { |position| create(:chunk, document:, position:) }
      create(:collection_membership, collection:, document:, origin: "manual")
      create(:collection_user, collection:, user:)
    end

    context "when the collection is one this chat draws on" do
      it "reports success" do
        expect(result[:status]).to eq("ok")
      end

      it "gives the id read_document takes" do
        expect(result[:results].map { it["id"] }).to eq([document.id])
      end

      it "says how much document there is to read" do
        expect(result[:results].first["chunks"]).to eq(3)
      end

      it "says where in the collection it listed, and out of how much" do
        expect(result[:documents]).to eq({ from: 1, to: 1, total: 1 })
      end

      it "tells the model a listing is not something to cite" do
        expect(result[:instruction]).to include("write no citation handles")
      end

      it "tells it to say what the listing shows" do
        expect(result[:instruction]).to include("Tell the user what this shows")
      end

      it "points at what the ids are for" do
        expect(result[:instruction]).to include("read_document")
      end

      it "says nothing about more when it listed the lot" do
        expect(result[:instruction]).not_to include("call list_documents again")
      end
    end

    context "when more of the collection remains" do
      before { 2.times { create(:collection_membership, collection:, document: create(:document), origin: "manual") } }

      it "tells the model where to carry on from" do
        expect(tool.execute(collection: collection.slug, limit: 2)[:instruction]).to include("from: 3")
      end
    end

    # Telling "no such collection" apart from "not one of yours" would turn a
    # guessed slug into a way of counting what exists behind grants this reader
    # doesn't hold.
    describe "a slug it should not be able to list" do
      let(:refusals) do
        [
          tool.execute(collection: create(:collection, name: "Payroll").slug),
          tool.execute(collection: "no-such-collection")
        ]
      end

      it "refuses both identically, so a guess reveals nothing" do
        expect(refusals.first).to eq(refusals.last)
      end

      it "refuses" do
        expect(refusals.map { it[:status] }).to all(eq("not_found"))
      end

      it "names no collection it would not have listed" do
        expect(refusals.first.to_s).not_to include("Payroll")
      end
    end

    context "when the chat is scoped to a different collection" do
      let(:user) { create(:user, role: :admin) }
      let(:scope) { Retrieval::Scope.from_params({ c: [create(:collection).slug] }, user:) }

      it "refuses an admin the same way it refuses a stranger" do
        expect(result).to eq(tool.execute(collection: "no-such-collection"))
      end
    end

    context "when the collection holds nothing this chat can draw on" do
      before { CollectionMembership.update_all(removed_at: Time.current) }

      it "says the collection is empty rather than that it does not exist" do
        expect(result[:status]).to eq("no_documents")
      end

      it "tells the model not to fill the gap from memory" do
        expect(result[:instruction]).to include("own knowledge")
      end
    end

    context "when the page starts past the end" do
      it "says the page is wrong rather than the collection is empty" do
        expect(tool.execute(collection: collection.slug, from: 99)[:status]).to eq("out_of_range")
      end

      it "says how much the collection actually holds" do
        expect(tool.execute(collection: collection.slug, from: 99)[:documents]).to eq({ total: 1 })
      end
    end

    context "when the model has already spent its budget" do
      subject(:tool) { described_class.new(corpus:, handles:, max_rounds: 1) }

      before { tool.execute(collection: collection.slug) }

      it "refuses rather than halting the turn mid-sentence" do
        expect(result[:status]).to eq("budget_spent")
      end
    end

    context "with an observer watching the turn" do
      let(:observer) { spy("observer") }

      it "tells it a listing started, so the UI can show it running" do
        result
        expect(observer).to have_received(:listing_started)
      end

      it "hands it the listing to record" do
        result
        expect(observer).to have_received(:listing_finished).with(an_instance_of(Retrieval::Listing))
      end
    end
  end

  describe "#description" do
    subject(:tool) { described_class.new(corpus:, handles: nil) }

    let(:corpus) { instance_double(Retrieval::Corpus, label: "the Security Handbook") }

    it "tells the model what it may list" do
      expect(tool.description).to include("the Security Handbook")
    end

    it "points it at list_collections for the slug" do
      expect(tool.description).to include("list_collections")
    end
  end
end
