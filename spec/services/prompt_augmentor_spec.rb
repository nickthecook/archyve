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
  let(:graph_entity) { create(:graph_entity, summary: "THe summary") }
  let(:search_hits) do
    [
      Search::SearchHit.new(chunks[0], 200.0),
      Search::SearchHit.new(chunks[1], 220.0),
      Search::SearchHit.new(graph_entity, 240.0),
    ]
  end

  describe "#prompt" do
    it "has the correct content" do
      allow_any_instance_of(Search::SearchHit).to receive(:relevant).and_return(true) # rubocop:todo RSpec/AnyInstance

      content = <<~CONTENT
        You are given a query to answer based on some given textual context, all inside xml tags.
        If the answer is not in the context but you think you know the answer, explain that to the user then answer with your own knowledge.

        <context>
        <context_item name="#{search_hits.first.name}">
        <filename>#{chunks.first.document.filename}</filename>
        <text>#{chunks.first.content}</text>
        </context_item>
        <context_item name="#{search_hits.second.name}">
        <url>#{chunks.second.document.link}</url>
        <scraped>#{chunks.second.document.created_at}</scraped>
        <text>#{chunks.second.content}</text>
        </context_item>
        <context_item name="#{search_hits.third.name}">
        <text>#{graph_entity.summary}</text>
        </context_item>
        </context>

        Query: #{message.content}
      CONTENT

      expect(subject.prompt).to eq(content)
    end

    context "when no search_hits are given" do
      let(:search_hits) { [] }

      it "returns no prompt" do
        expect(subject.prompt).to eq "The query found hits, but none were relevant. Query: #{message.content}\n"
      end
    end
  end

  describe "#augment" do
    it "updates the message with the augmented prompt" do
      # TODO: Avoid rubocop:todo
      allow_any_instance_of(Search::SearchHit).to receive(:relevant).and_return(true) # rubocop:todo RSpec/AnyInstance

      expect { subject.augment }.to change { message.reload.prompt }.from(nil).to(/You are given a query/)
    end

    it "creates MessageAugmentations" do
      expect { subject.augment }.to change(MessageAugmentation, :count).from(0).to(3)
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
