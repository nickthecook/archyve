RSpec.describe MessageAugmentor do
  subject { described_class.new(message) }

  let(:message) { conversation.messages.last }
  let(:conversation) { create(:conversation_with_collection, search_collections:, conversation_collections:) }
  let(:search_collections) { true }
  let(:conversation_collections) { [build(:conversation_collection, collection:)] }
  let(:collection) { create(:collection) }

  let(:searchn) { instance_double(Search::SearchN, search: search_hits) }
  let(:search_hits) do
    [
      Search::SearchHit.new(chunks[0], 200.0),
      Search::SearchHit.new(chunks[1], 220.0),
    ]
  end
  let(:chunks) { create_list(:chunk, 2, document:) }
  let(:document) { create(:document, collection:) }

  let(:prompt_augmentor) { instance_double(PromptAugmentor, augment: nil) }

  before do
    allow(Search::SearchN).to receive(:new).and_return(searchn)
    allow(PromptAugmentor).to receive(:new).and_return(prompt_augmentor)
  end

  shared_examples "searches collections" do
    it "calls PromptAugmentor" do
      subject.execute
      expect(PromptAugmentor).to have_received(:new).with(message, search_hits)
      expect(prompt_augmentor).to have_received(:augment).with(no_args)
    end

    it "calls Search::SearchN" do
      subject.execute
      expect(Search::SearchN).to have_received(:new).with(
        containing_exactly(collection),
        num_results: 10,
        traceable: conversation
      )
      expect(searchn).to have_received(:search).with(message.content)
    end
  end

  describe "#execute" do
    include_examples "searches collections"

    context "when search is disabled for conversation" do
      let(:search_collections) { false }

      it "does not call PromptAugmentor" do
        subject.execute
        expect(PromptAugmentor).not_to have_received(:new)
      end

      it "does not search collections" do
        subject.execute
        expect(Search::SearchN).not_to have_received(:new)
      end
    end

    context "when conversation has no associated collections" do
      let(:conversation_collections) { [] }

      include_examples "searches collections"
    end
  end
end
