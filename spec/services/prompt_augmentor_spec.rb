RSpec.describe PromptAugmentor do
  subject { described_class.new(message, search_hits) }

  let(:message) { create(:message, content: "What tool should I use to install Ruby?", conversation:) }
  let(:conversation) { create(:conversation, messages: []) }
  let(:chunks) do
    [
      create(:chunk),
      create(:chunk_from_web),
    ]
  end
  let(:search_hits) do
    [
      Search::SearchHit.new(chunks[0], 200.0),
      Search::SearchHit.new(chunks[1], 220.0),
    ]
  end

  describe "#prompt" do
    it "has the correct content" do
      content = <<~CONTENT
        You are given a query to answer based on some given textual context, all inside xml tags.
        If the answer is not in the context but you think you know the answer, explain that to the user then answer with your own knowledge.

        <context>\n<filename>#{chunks.first.document.filename}</filename>
        <text>#{chunks.first.content}</text>\n</context>\n<context>
        <url>#{chunks.second.document.link}</url>\n<scraped>#{chunks.second.document.created_at}</scraped>
        <text>#{chunks.second.content}</text>
        </context>
        <user_query>
        What tool should I use to install Ruby?
        <user_query>
      CONTENT

      expect(subject.prompt).to eq(content)
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
      expect { subject.augment }.to change { message.reload.prompt }.from(nil).to(/You are given a query/)
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
