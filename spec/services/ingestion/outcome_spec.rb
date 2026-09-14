require "rails_helper"

RSpec.describe Ingestion::Outcome do
  describe ".classify" do
    subject(:failure) { described_class.classify(error, stage: :embed) }

    # The split that matters: a kind is the answer to "who fixes this?", so
    # every context here is a different person being sent somewhere.
    context "when a service didn't answer" do
      let(:error) { Faraday::ConnectionFailed.new("connection refused") }

      it "is unreachable" do
        expect(failure.kind).to eq("unreachable")
      end
    end

    context "when the embedding server answered with a 5xx" do
      let(:error) { RubyLLM::ServiceUnavailableError.new("overloaded") }

      it "is unreachable too — nobody fixes that with a different file" do
        expect(failure.kind).to eq("unreachable")
      end
    end

    context "when the embedding server rejected our credentials" do
      let(:error) { RubyLLM::UnauthorizedError.new("bad key") }

      it "is a configuration problem, not an outage" do
        expect(failure.kind).to eq("not_configured")
      end
    end

    context "when docling refused the file" do
      let(:error) { Docling::Client::ConversionFailed.new("docling returned 422") }

      it "blames the document" do
        expect(failure.kind).to eq("conversion_rejected")
      end
    end

    context "when nothing is configured to embed with" do
      let(:error) { Embeddings::Embed::NotConfigured.new("no embedding model") }

      it "says so" do
        expect(failure.kind).to eq("not_configured")
      end
    end

    context "when the error is one nobody has classified" do
      let(:error) { ArgumentError.new("nope") }

      it "admits it rather than guessing" do
        expect(failure.kind).to eq("internal")
      end
    end

    describe "the detail" do
      let(:error) { Docling::Client::Unreachable.new("docling did not respond") }

      it "keeps the class, which is half the answer" do
        expect(failure.detail).to eq("Docling::Client::Unreachable: docling did not respond")
      end

      context "when the message is enormous" do
        let(:error) { Docling::Client::Unreachable.new("x" * 2_000) }

        it "is truncated to something a column and a page can both hold" do
          expect(failure.detail.length).to eq(described_class::DETAIL_LIMIT)
        end
      end
    end

    describe "the stage" do
      let(:error) { ArgumentError.new("nope") }

      it "comes from the caller, since only the pipeline knows where it was" do
        expect(failure.stage).to eq("embed")
      end

      context "when the failure happened outside any stage" do
        subject(:failure) { described_class.classify(error) }

        it "has none rather than a misleading one" do
          expect(failure.stage).to be_nil
        end
      end
    end
  end
end
