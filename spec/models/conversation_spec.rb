require "rails_helper"

RSpec.describe Conversation do
  describe "#retrieval_scope" do
    subject(:conversation) { create(:conversation, user:, scope:) }

    let(:result) { conversation.retrieval_scope }

    let(:user) { create(:user) }
    let(:collection) { create(:collection, name: "Handbook") }

    context "when no scope was chosen" do
      let(:scope) { {} }

      it "is unrestricted" do
        expect(result).to be_nil
      end

      it "says so in words, for the model's instructions" do
        expect(conversation.scope_label).to eq("your whole archive")
      end

      it "searches" do
        expect(conversation).to be_searches_archive
      end
    end

    # The picker with everything unticked. An empty selection is a scope of its
    # own — it means "search nothing" — and the one thing it must never do is
    # collapse back into All.
    context "when no collection was chosen" do
      let(:scope) { { "c" => [] } }

      it "is a scope rather than the absence of one" do
        expect(result).not_to be_nil
      end

      it "retrieves nothing" do
        expect(result.document_ids).to be_empty
      end

      it "says so in words" do
        expect(conversation.scope_label).to eq("no collections")
      end

      it "is not a chat that searches" do
        expect(conversation).not_to be_searches_archive
      end
    end

    context "when scoped to a collection they may read" do
      let(:scope) { { "c" => [collection.slug] } }

      before { create(:collection_user, collection:, user:) }

      it "names it" do
        expect(conversation.scope_label).to eq("Handbook")
      end

      it "narrows retrieval to it" do
        expect(result.document_ids).not_to be_nil
      end
    end

    # The reason the scope is stored as a specification rather than a resolved
    # list of ids: a grant revoked on the tenth turn has to take effect.
    context "when their access is revoked after the conversation starts" do
      let(:scope) { { "c" => [collection.slug] } }

      before do
        create(:collection_user, collection:, user:)
        conversation.retrieval_scope
        CollectionUser.find_by!(collection:, user:).destroy
      end

      it "stops naming the collection" do
        expect(conversation.scope_label).not_to eq("Handbook")
      end

      it "resolves to nothing" do
        expect(result.document_ids).to be_empty
      end
    end
  end

  describe "#next_message_position" do
    subject(:conversation) { create(:conversation) }

    let(:result) { conversation.next_message_position }

    context "when the conversation is empty" do
      it "starts at one" do
        expect(result).to eq(1)
      end
    end

    context "when it already has turns" do
      before { create(:message, conversation:, position: 3) }

      it "follows the last one" do
        expect(result).to eq(4)
      end
    end
  end
end
