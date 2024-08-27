RSpec.describe PromptAugmentor do
  subject { described_class.new(message, search_hits) }

  let(:message) { create(:message, content: "What tool should I use to install Ruby?", conversation:) }
  let(:conversation) { create(:conversation, messages: []) }
  let(:chunks) { create_list(:chunk, 2) }
  let(:search_hits) do
    [
      Search::SearchHit.new(chunks[0], 200.0),
      Search::SearchHit.new(chunks[1], 220.0),
    ]
  end

  describe "#prompt" do
    it "has the correct content" do
      expect(subject.prompt).to eq(
        <<~PROMPT
          Here is some context that may help you answer the following question:

          #{chunks.first.content}

          #{chunks.second.content}

          Question: What tool should I use to install Ruby?
        PROMPT
      )
    end

    context "when no search_hits are given" do
      let(:search_hits) { [] }

      it "returns just the original prompt" do
        expect(subject.prompt).to eq(message.content)
      end
    end
  end

  describe "#augment" do
    it "updates the message with the augmented prompt" do
      expect { subject.augment }.to change { message.reload.prompt }.from(nil).to(/Here is some context/)
    end

    it "creates MessageAugmentations" do
      expect { subject.augment }.to change(MessageAugmentation, :count).from(0).to(2)
    end

    it "links the Message and the search hit references with MessageAugmentations" do
      subject.augment

      expect(MessageAugmentation.first.message).to eq(message)
      expect(MessageAugmentation.first.augmentation).to eq(search_hits.first.reference)
      expect(MessageAugmentation.second.message).to eq(message)
      expect(MessageAugmentation.second.augmentation).to eq(search_hits.second.reference)
    end
  end
end
