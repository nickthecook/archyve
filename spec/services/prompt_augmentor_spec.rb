RSpec.describe PromptAugmentor do
  subject { described_class.new(message, search_hits) }

  let(:message) { create(:message, content: "What tool should I use to install Ruby?", conversation:) }
  let(:conversation) { create(:conversation, messages: []) }
  let(:chunks) do
    [
      create(:chunk),
      # create(:chunk),
    ]
  end
  let(:search_hits) do
    [
      Search::SearchHit.new(chunks[0], 200.0),
      # Search::SearchHit.new(chunks[1], 220.0),
    ]
  end

  # TODO: make part of #prompt test below
  describe "#prompt for doc from web" do
    it "has the correct content" do
      c = create(:chunk_from_web)
      hs = [Search::SearchHit.new(c, 240.0)]
      p = described_class.new(message, hs)
      # TODO: Figure out why needed:
      allow_any_instance_of(Document).to receive(:web?).and_return(true) # rubocop:disable RSpec/AnyInstance
      expect(p.prompt).to eq(
        "You are given a question to answer based on some given textual context, all inside xml tags.\nIf the answer is not in the context but you think you know the answer, explain that to the user then answer with your own knowledge.\n\n<context>\n<url>#{c.document.link}</url>\n<scraped>#{c.document.created_at}</scraped>\n<text>#{c.content}</text>\n</context>\n<user_question>\nWhat tool should I use to install Ruby?\n<user_question>\n"
      )
    end
  end

  describe "#prompt" do
    it "has the correct content" do
      expect(subject.prompt).to eq(
        "You are given a question to answer based on some given textual context, all inside xml tags.\nIf the answer is not in the context but you think you know the answer, explain that to the user then answer with your own knowledge.\n\n<context>\n<filename>#{chunks.first.document.filename}</filename>\n<text>#{chunks.first.content}</text>\n</context>\n<user_question>\nWhat tool should I use to install Ruby?\n<user_question>\n"
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
    # TODO: Fix these for new xml context
    it "updates the message with the augmented prompt", pending: 'fix this test1' do
      expect { subject.augment }.to change { message.reload.prompt }.from(nil).to(/Here is some context/)
    end

    it "creates MessageAugmentations", pending: 'fix this test2' do
      expect { subject.augment }.to change(MessageAugmentation, :count).from(0).to(2)
    end

    it "links the Message and the search hit references with MessageAugmentations", pending: 'fix this test3' do
      subject.augment

      expect(MessageAugmentation.first.message).to eq(message)
      expect(MessageAugmentation.first.augmentation).to eq(search_hits.first.reference)
      expect(MessageAugmentation.second.message).to eq(message)
      expect(MessageAugmentation.second.augmentation).to eq(search_hits.second.reference)
    end
  end
end
