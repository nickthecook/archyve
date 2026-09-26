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

    # Handles run on across a turn rather than restarting in each block, so
    # prose after a second search can still cite the first. Resolving against
    # only the nearest block above linked [1] to whatever the *latest* search
    # put first, which is a citation pointing at the wrong document.
    context "when the turn searched again before writing this prose" do
      let(:prose) { create(:segment, message:, position: 3, content: "As above [1], and also [7].") }
      let(:second) { create(:retrieval_segment, message:, position: 2) }
      let(:elsewhere) { create(:document, title: "Runbook") }

      before { create(:hit, segment: second, handle: 7, chunk: create(:chunk, document: elsewhere), document: elsewhere) }

      it "still resolves a handle from the first search" do
        expect(result).to include("/documents/#{document.id}")
      end

      it "resolves one from the second as well" do
        expect(result).to include("/documents/#{elsewhere.id}")
      end
    end

    # Read passages are cited exactly like searched ones — they are passages
    # the model was shown, which is all a handle ever means.
    context "when the turn read a document before writing this prose" do
      let(:prose) { create(:segment, message:, position: 3, content: "It says so [9].") }
      let(:reading) { create(:reading_segment, message:, position: 2) }
      let(:manual) { create(:document, title: "Runbook") }

      before { create(:hit, :read, segment: reading, handle: 9, chunk: create(:chunk, document: manual), document: manual) }

      it "links what was read" do
        expect(result).to include("/documents/#{manual.id}")
      end
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
