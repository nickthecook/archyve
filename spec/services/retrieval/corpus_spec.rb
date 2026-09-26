require "rails_helper"

RSpec.describe Retrieval::Corpus do
  describe "#documents" do
    subject(:corpus) { described_class.new(user:, scope:) }

    let(:user) { create(:user) }
    let(:scope) { nil }

    let(:collection) { create(:collection) }
    let(:document) { create(:document, title: "Handbook") }

    before { create(:collection_membership, collection:, document:, origin: "manual") }

    context "when they hold a grant on the collection it is in" do
      before { create(:collection_user, collection:, user:) }

      it "includes it" do
        expect(corpus.documents).to include(document)
      end
    end

    context "when they hold no grant on it" do
      it "excludes it" do
        expect(corpus.documents).not_to include(document)
      end
    end

    # Deliberately retrievable_by rather than reachable_by: reading has to draw
    # on exactly what searching draws on, and a document in no collection is in
    # nobody's corpus even when its source is theirs to manage.
    context "when it is unfiled but produced by a source they manage" do
      let(:user) { create(:user, role: :operator) }
      let(:document) { create(:document, source: create(:source, user:)) }

      before { CollectionMembership.find_by(document:)&.destroy }

      it "excludes it" do
        expect(corpus.documents).not_to include(document)
      end
    end

    context "when they are an admin" do
      let(:user) { create(:user, role: :admin) }

      it "includes it without any grant" do
        expect(corpus.documents).to include(document)
      end
    end

    context "when the scope names a different collection" do
      let(:user) { create(:user, role: :admin) }
      let(:other) { create(:collection) }
      let(:scope) { Retrieval::Scope.from_params({ c: [other.slug] }, user:) }

      it "excludes it, even from an admin" do
        expect(corpus.documents).not_to include(document)
      end
    end

    context "when the scope names the collection it is in" do
      let(:user) { create(:user, role: :admin) }
      let(:scope) { Retrieval::Scope.from_params({ c: [collection.slug] }, user:) }

      it "includes it" do
        expect(corpus.documents).to include(document)
      end
    end
  end

  describe "#collections" do
    subject(:corpus) { described_class.new(user:, scope:) }

    let(:user) { create(:user) }
    let(:scope) { nil }

    let(:collection) { create(:collection, name: "Security Handbook") }
    let(:document) { create(:document) }

    before { create(:collection_membership, collection:, document:, origin: "manual") }

    context "when they hold a grant on it" do
      before { create(:collection_user, collection:, user:) }

      it "includes it" do
        expect(corpus.collections).to include(collection)
      end
    end

    context "when they hold no grant on it" do
      it "excludes it" do
        expect(corpus.collections).not_to include(collection)
      end
    end

    # The scope is the conversation's corpus, and listing past it has the model
    # describing documents this chat cannot draw on.
    context "when the scope names a different collection" do
      let(:user) { create(:user, role: :admin) }
      let(:scope) { Retrieval::Scope.from_params({ c: [create(:collection).slug] }, user:) }

      it "excludes it, even from an admin" do
        expect(corpus.collections).not_to include(collection)
      end
    end

    # A chat pinned to one document still reaches it through a collection.
    context "when the scope names one document" do
      let(:user) { create(:user, role: :admin) }
      let(:scope) { Retrieval::Scope.from_params({ doc: document.id }, user:) }

      it "answers with the collections that document is filed in" do
        expect(corpus.collections).to contain_exactly(collection)
      end
    end
  end

  describe "#filters" do
    # Search leans on an empty list to skip the join to documents entirely, so
    # "unrestricted" has to come back as nothing rather than as a filter that
    # happens to match everything.
    context "with an admin and no scope" do
      subject(:corpus) { described_class.new(user: create(:user, role: :admin)) }

      it "restricts nothing" do
        expect(corpus.filters).to be_empty
      end
    end

    context "with an ordinary reader" do
      subject(:corpus) { described_class.new(user: create(:user)) }

      it "restricts to what they may read" do
        expect(corpus.filters.size).to eq(1)
      end
    end
  end

  describe "#label" do
    context "without a scope" do
      subject(:corpus) { described_class.new(user: create(:user)) }

      it "names the whole archive" do
        expect(corpus.label).to eq("your whole archive")
      end
    end

    context "with a scope" do
      subject(:corpus) { described_class.new(user:, scope:) }

      let(:user) { create(:user, role: :admin) }
      let(:collection) { create(:collection, name: "Security Handbook") }
      let(:scope) { Retrieval::Scope.from_params({ c: [collection.slug] }, user:) }

      it "names what it was narrowed to" do
        expect(corpus.label).to eq("Security Handbook")
      end
    end
  end
end
