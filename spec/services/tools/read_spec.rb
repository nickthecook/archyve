require "rails_helper"

RSpec.describe Tools::Read do
  describe "#execute" do
    subject(:tool) { described_class.new(corpus:, handles:, observer:) }

    let(:result) { tool.execute(document: document.id, from:, to:) }

    let(:user) { create(:user) }
    let(:scope) { nil }
    let(:corpus) { Retrieval::Corpus.new(user:, scope:) }
    let(:handles) { Retrieval::Handles.new }
    let(:observer) { nil }
    let(:from) { 2 }
    let(:to) { 3 }

    let(:collection) { create(:collection) }
    let(:document) { create(:document, title: "Security Handbook") }

    before do
      5.times { |position| create(:chunk, document:, position:, content: "Chunk #{position + 1}.") }
      create(:collection_membership, collection:, document:, origin: "manual")
      create(:collection_user, collection:, user:)
    end

    context "when the document is readable" do
      it "reports success" do
        expect(result[:status]).to eq("ok")
      end

      it "gives back the passages it was asked for" do
        expect(result[:passages].map { it[:text] }).to eq(["Chunk 2.", "Chunk 3."])
      end

      it "numbers each passage as documents#show does" do
        expect(result[:passages].map { it[:chunk] }).to eq([2, 3])
      end

      it "says where in the document it read, and out of how much" do
        expect(result[:chunks]).to eq({ from: 2, to: 3, total: 5 })
      end

      it "gives each passage a handle to cite" do
        expect(result[:passages].map { it[:handle] }).to eq([1, 2])
      end

      # Said only when true: a model told every time that more might remain
      # learns to ignore it.
      it "says nothing about more when it read to the end" do
        expect(tool.execute(document: document.id, from: 1, to: 5)).not_to have_key(:instruction)
      end
    end

    context "when more of the document remains" do
      let(:to) { 2 }

      it "tells the model where to carry on from" do
        expect(result[:instruction]).to include("from: 3")
      end
    end

    # The whole point of an id rather than a handle: the model arrives at a
    # document from a search, a listing, or nowhere at all, and one name works
    # for all three. What it cannot do is widen what it may see.
    describe "an id it should not be able to read" do
      let(:refusals) do
        [
          # A document that exists, in a collection they were never granted.
          begin
            CollectionUser.where(user:).destroy_all
            tool.execute(document: document.id)
          end,
          # A document id that does not exist at all.
          tool.execute(document: 999_999)
        ]
      end

      it "refuses" do
        expect(refusals.map { it[:status] }).to all(eq("not_found"))
      end

      # Telling them apart would turn a guessed id into a way of counting what
      # exists behind grants this reader doesn't hold.
      it "refuses both identically, so a guess reveals nothing" do
        expect(refusals.first).to eq(refusals.last)
      end

      it "names no document it would not have shown" do
        expect(refusals.first.to_s).not_to include("Security Handbook")
      end
    end

    context "when the chat is scoped to a different collection" do
      let(:user) { create(:user, role: :admin) }
      let(:scope) { Retrieval::Scope.from_params({ c: [create(:collection).slug] }, user:) }

      it "refuses an admin the same way it refuses a stranger" do
        expect(result).to eq(tool.execute(document: 999_999))
      end
    end

    # A document with text coming is not a document with no text, and the
    # difference is what the model tells the user.
    context "when the document has not been processed" do
      before { Chunk.where(document:).destroy_all }

      it "says so rather than reporting it missing" do
        expect(result[:status]).to eq("not_processed")
      end

      it "tells the model not to fill the gap from memory" do
        expect(result[:instruction]).to include("own knowledge")
      end
    end

    context "when the range starts past the end of the document" do
      let(:from) { 99 }
      let(:to) { 120 }

      it "says the range is wrong rather than the document is missing" do
        expect(result[:status]).to eq("out_of_range")
      end

      it "says how long the document actually is" do
        expect(result[:chunks]).to eq({ total: 5 })
      end
    end

    context "when the model has already spent its budget" do
      subject(:tool) { described_class.new(corpus:, handles:, max_rounds: 1) }

      before { tool.execute(document: document.id, from: 1, to: 1) }

      it "refuses rather than halting the turn mid-sentence" do
        expect(result[:status]).to eq("budget_spent")
      end

      it "tells it to answer from what it has" do
        expect(result[:instruction]).to include("do not answer from your own knowledge")
      end
    end

    context "with an observer watching the turn" do
      let(:observer) { spy("observer") }

      it "tells it a read started, so the UI can show it running" do
        result
        expect(observer).to have_received(:reading_started).with(document.id)
      end

      it "hands it the reading to record" do
        result
        expect(observer).to have_received(:reading_finished).with(an_instance_of(Retrieval::Reading))
      end
    end
  end

  describe "handles shared with the search tool" do
    subject(:read) { described_class.new(corpus:, handles:) }

    let(:user) { create(:user, role: :admin) }
    let(:corpus) { Retrieval::Corpus.new(user:) }
    let(:handles) { Retrieval::Handles.new }
    let(:document) { create(:document, title: "Security Handbook") }

    before { 3.times { |position| create(:chunk, document:, position:) } }

    # One namespace for the turn: a read after a search that returned six hits
    # starts at seven, so "[7]" in the answer means one passage.
    it "carries on from where the search left off" do
      handles.assign(Array.new(6) { Retrieval::Hit.new(chunk: create(:chunk), document:) })
      expect(read.execute(document: document.id)[:passages].first[:handle]).to eq(7)
    end
  end

  describe "#description" do
    subject(:tool) { described_class.new(corpus:, handles: Retrieval::Handles.new) }

    let(:corpus) { instance_double(Retrieval::Corpus, label: "the Security Handbook") }

    it "tells the model what it may read" do
      expect(tool.description).to include("the Security Handbook")
    end

    it "tells it an id has to have been given, not guessed" do
      expect(tool.description).to include("already been shown")
    end
  end
end
