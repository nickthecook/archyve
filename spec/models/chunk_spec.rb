require 'rails_helper'

RSpec.describe Chunk do
  subject { create(:chunk, excerpt:, embedding_content:) }

  let(:document) { create(:document) }
  let(:excerpt) { "subject" }
  let(:embedding_content) { "surround subject sound" }
  let(:chunks) { document.chunks.sort }

  describe "#create!" do
    context "without embedding_content" do
      let(:embedding_content) { nil }

      it "fails" do
        expect { subject }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  context "when using chunks" do
    before do
      create(:chunk, document:)
      create(:chunk, document:)
      document.chunks << subject
      create(:chunk, document:)
      create(:chunk, document:)

      document.reload
    end

    describe "#previous" do
      it "returns the previous chunk" do
        expect(subject.previous).to contain_exactly(chunks[1])
      end

      it "returns multiple chunks" do
        expect(subject.previous(2)).to eq(chunks[0..1])
      end

      it "stops at the beginning of the list" do
        expect(subject.previous(3)).to eq(chunks[0..1])
      end
    end

    describe "#next" do
      it "returns the next chunk" do
        expect(subject.next).to contain_exactly(chunks[-2])
      end

      it "returns multiple chunks" do
        expect(subject.next(2)).to eq(chunks[3..4])
      end

      it "stops at the end of the list" do
        expect(subject.next(3)).to eq(chunks[3..4])
      end
    end

    describe "#embedding_content=" do
      it "fails since property is readonly" do
        expect { subject.embedding_content = nil }.to raise_error(ActiveRecord::ReadonlyAttributeError)
      end
    end

    describe "#excerpt=" do
      it "fails since property is readonly" do
        expect { subject.excerpt = nil }.to raise_error(ActiveRecord::ReadonlyAttributeError)
      end
    end

    describe "#location_summary=" do
      it "fails since property is readonly" do
        expect { subject.location_summary = nil }.to raise_error(ActiveRecord::ReadonlyAttributeError)
      end
    end

    describe "#surrounding_content=" do
      it "fails since property is readonly" do
        expect { subject.surrounding_content = nil }.to raise_error(ActiveRecord::ReadonlyAttributeError)
      end
    end

    describe "#headings=" do
      it "fails since property is readonly" do
        expect { subject.headings = nil }.to raise_error(ActiveRecord::ReadonlyAttributeError)
      end
    end

    describe "#embedding_content" do
      # context "when embedding_content is not set" do
      #   before do
      #     chunk = subject
      #     chunk.embedding_content = nil
      #   end

      #   it "returns the excerpt" do
      #     expect(subject.embedding_content).to eq(excerpt)
      #   end
      # end

      it "returns the embedding content" do
        expect(subject.embedding_content).to eq("surround subject sound")
      end
    end
  end
end
