RSpec.describe PromptAugmentor do
  subject { described_class.new(message.content, search_hits) }

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
  end
end
