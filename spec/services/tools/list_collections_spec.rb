require "rails_helper"

RSpec.describe Tools::ListCollections do
  describe "#execute" do
    subject(:tool) { described_class.new(corpus:, handles:, observer:) }

    let(:result) { tool.execute }

    let(:user) { create(:user) }
    let(:scope) { nil }
    let(:corpus) { Retrieval::Corpus.new(user:, scope:) }
    let(:handles) { Retrieval::Handles.new }
    let(:observer) { nil }

    let(:source) { create(:source, name: "Wiki") }
    let(:collection) { create(:collection, name: "Security Handbook") }

    before do
      collection.sources << source
      create(:collection_membership, collection:, document: create(:document, source:), origin: "manual")
      create(:collection_user, collection:, user:)
    end

    context "when the chat draws on collections" do
      it "reports success" do
        expect(result[:status]).to eq("ok")
      end

      it "names each one by the slug list_documents takes" do
        expect(result[:collections].map { it["slug"] }).to eq([collection.slug])
      end

      it "says where the documents came from" do
        expect(result[:collections].first["sources"]).to eq(["Wiki"])
      end

      # A model that writes [3] meaning "the third collection" produces a
      # citation resolving to whatever passage 3 happened to be.
      it "tells the model a listing is not something to cite" do
        expect(result[:instruction]).to include("write no citation handles")
      end

      # Phrased as permission, because a model told only that a listing cannot
      # be cited goes quiet on the question the listing just answered.
      it "tells it to say what the listing shows" do
        expect(result[:instruction]).to include("Tell the user what this shows")
      end

      # The failure this exists for: the model lists, works its next call out in
      # the analysis channel, and ends the turn having answered nothing.
      it "names the call that finishes the errand" do
        expect(result[:instruction]).to include("call list_documents now")
      end
    end

    context "when the archive has no collections in it" do
      let(:user) { create(:user, role: :admin) }

      before { Collection.destroy_all }

      it "says it listed nothing rather than coming back with an empty list" do
        expect(result[:status]).to eq("no_collections")
      end

      it "tells the model not to fill the gap from memory" do
        expect(result[:instruction]).to include("own knowledge")
      end
    end

    context "when the model has already spent its budget" do
      subject(:tool) { described_class.new(corpus:, handles:, max_rounds: 1) }

      before { tool.execute }

      it "refuses rather than halting the turn mid-sentence" do
        expect(result[:status]).to eq("budget_spent")
      end
    end

    # The model may put anything in a call it was told takes nothing, and a
    # listing is a better answer than an argument error.
    context "when the model sends a parameter it was never offered" do
      it "lists anyway" do
        expect(tool.execute(collection: "security-handbook")[:status]).to eq("ok")
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

  describe "#params_schema" do
    subject(:tool) { described_class.new(corpus: instance_double(Retrieval::Corpus), handles: nil) }

    it "offers the model nothing to choose: the scope is bound" do
      expect(tool.params_schema["properties"]).to be_empty
    end
  end

  describe "#description" do
    subject(:tool) { described_class.new(corpus:, handles: nil) }

    let(:corpus) { instance_double(Retrieval::Corpus, label: "the Security Handbook") }

    it "tells the model the listing feeds list_documents" do
      expect(tool.description).to include("list_documents")
    end
  end
end
