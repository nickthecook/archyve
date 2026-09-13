require "rails_helper"

RSpec.describe Views::Conversations::Cited do
  describe "#call" do
    subject(:cited) { described_class.new(segment: prose) }

    let(:result) { cited.call }

    let(:message) { create(:message, conversation: create(:conversation), role: "assistant") }
    let(:retrieval) { create(:retrieval_segment, message:, position: 1) }
    let(:prose) { create(:segment, message:, position: 2, content:) }

    let(:document) { create(:document, title: "SHS-2920 manual") }
    let(:clearances) { create(:chunk, document:) }
    let(:insulation) { create(:chunk, document:) }

    before do
      create(:hit, segment: retrieval, handle: 1, chunk: clearances, document:)
      create(:hit, segment: retrieval, handle: 2, chunk: insulation, document:)
    end

    context "when the model cites with square brackets" do
      let(:content) { "Press [Registration] first [1]." }

      it "links the citation" do
        expect(result).to include("/documents/#{document.id}")
      end

      # A bracketed word is not a handle; only digits are.
      it "leaves bracketed prose alone" do
        expect(result).to include("[Registration]")
      end
    end

    # gpt-oss cites this way, and a citation that doesn't match doesn't link —
    # which is the whole feature gone.
    context "when the model cites with CJK brackets" do
      let(:content) { "The PIN is overwritten 【1】." }

      it "links it just the same" do
        expect(result).to include("/documents/#{document.id}")
      end

      it "does not leave the marker as literal text" do
        expect(result).not_to include("【1】")
      end
    end

    context "when the model cites with fullwidth brackets" do
      let(:content) { "The PIN is overwritten ［1］." }

      it "links it just the same" do
        expect(result).to include("/documents/#{document.id}")
      end
    end

    context "when the model groups several sources in one bracket" do
      let(:content) { "Both agree [1, 2]." }

      it "links each one" do
        expect(result.scan(%r{/documents/#{document.id}}).size).to eq(2)
      end

      # The point of resolving handles per retrieval block: two citations of the
      # same document must land on the two different passages that earned them,
      # or the reader is back to hunting for the chunk themselves.
      it "sends each handle to its own chunk" do
        expect(result).to include("#chunk_#{clearances.id}").and include("#chunk_#{insulation.id}")
      end
    end

    # The failure this whole scheme exists to prevent: a model inventing a
    # source. An unretrieved handle is shown as the literal thing it is rather
    # than dressed up as a link to something.
    context "when the model cites a handle it was never given" do
      let(:content) { "As documented [7]." }

      it "links nothing" do
        expect(result).not_to include("<a")
      end

      it "shows the marker as plain text" do
        expect(result).to include("[7]")
      end
    end

    context "when a group mixes a real handle with an invented one" do
      let(:content) { "Both agree [1, 7]." }

      it "keeps the good citation" do
        expect(result).to include("/documents/#{document.id}")
      end

      it "does not invent a link for the other" do
        expect(result.scan("<a").size).to eq(1)
      end
    end
  end
end
