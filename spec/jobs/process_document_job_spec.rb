require "rails_helper"

RSpec.describe ProcessDocumentJob do
  subject(:job) { described_class.new }

  let(:document) { create(:document, :with_file) }
  let(:items) { [Docling::Result::Item.new(text: "Body text.", label: "text", level: nil, page: nil)] }
  let(:docling_result) { instance_double(Docling::Result, items: items, partial?: false, errors: []) }
  let(:client) { instance_double(Docling::Client, convert: docling_result) }
  let(:vector) { Array.new(Embedding::DIMENSIONS) { 0.1 } }

  # The job stamps each vector with the corpus's embedding model, so one has to
  # exist for it to name.
  let!(:embedding_model) { create(:embedding_model) }

  before do
    allow(Docling::Client).to receive(:new).and_return(client)
    allow(Embeddings::Embed).to receive(:document).and_return(vector)
  end

  describe "#perform" do
    context "with a valid document" do
      it "marks the document processed" do
        job.perform(document)
        expect(document.reload.status).to eq("processed")
      end

      it "stores the extracted chunks" do
        expect { job.perform(document) }.to change { document.chunks.count }.from(0).to(1)
      end

      it "embeds each chunk with the corpus model" do
        job.perform(document)
        expect(document.chunks.first.embeddings.first.embedding_model).to eq(embedding_model.name)
      end
    end

    # The setting is only worth having if it reaches docling, and the document
    # is what decides — it is the thing that remembers what was chosen.
    describe "the OCR choice it converts with" do
      it "asks for OCR when the document wants it" do
        job.perform(document)
        expect(client).to have_received(:convert).with(anything, hash_including(ocr: true))
      end

      context "when the document's source has OCR turned off" do
        before { document.source.update!(ocr: false) }

        it "converts without it" do
          job.perform(document)
          expect(client).to have_received(:convert).with(anything, hash_including(ocr: false))
        end
      end
    end

    context "when the document has no attached file" do
      let(:document) { create(:document) }

      it "raises MissingFile" do
        expect { job.perform(document) }.to raise_error(Ingestion::MissingFile)
      end

      it "marks the document failed" do
        suppress(Ingestion::MissingFile) { job.perform(document) }
        expect(document.reload.status).to eq("failed")
      end

      it "records the failure facts" do
        suppress(Ingestion::MissingFile) { job.perform(document) }
        expect(document.reload).to have_attributes(outcome_stage: "extract", outcome_kind: "missing_file")
      end
    end

    context "when extraction fails" do
      before { allow(client).to receive(:convert).and_raise(Docling::Client::Error) }

      it "re-raises the error" do
        expect { job.perform(document) }.to raise_error(Docling::Client::Error)
      end

      it "marks the document failed" do
        suppress(Docling::Client::Error) { job.perform(document) }
        expect(document.reload.status).to eq("failed")
      end
    end

    # Docling converted the document and reported that a page didn't parse. The
    # pages that did parse are right there in the response, and throwing away a
    # sixty-page manual to punish one bad page is the behaviour this replaced.
    context "when docling converts the document only partly" do
      let(:docling_result) do
        instance_double(Docling::Result, items: items, partial?: true, errors: ["Page 2 failed to parse."])
      end

      it "keeps what did come through" do
        job.perform(document)
        expect(document.chunks.reload.pluck(:content)).to eq(["Body text."])
      end

      it "marks the document processed, because it is in the archive and searchable" do
        job.perform(document)
        expect(document.reload.status).to eq("processed")
      end

      it "records the shortfall rather than letting it pass as a clean run" do
        job.perform(document)
        expect(document.reload)
          .to have_attributes(outcome_stage: "extract", outcome_kind: "partial_extraction")
      end

      it "keeps docling's account of what it couldn't read" do
        job.perform(document)
        expect(document.reload.outcome_detail).to include("Page 2 failed to parse.")
      end

      # The case the guard exists for: a partial conversion whose surviving
      # pages held no text at all would otherwise be a processed document with
      # nothing in it, which nothing can ever retrieve.
      context "and nothing readable survived" do
        let(:items) { [] }

        it "fails instead of claiming to have processed an empty document" do
          suppress(Ingestion::NothingReadable) { job.perform(document) }
          expect(document.reload)
            .to have_attributes(status: "failed", outcome_stage: "chunk", outcome_kind: "conversion_rejected")
        end
      end
    end

    # The whole point of the outcome columns: a person reading the document page
    # can tell a dead service from a bad file without going near a log. Each
    # context is a different thing going wrong in production, and the assertion
    # is the diagnosis it leaves behind.
    describe "the recorded diagnosis" do
      def failure_of(document, error)
        allow(client).to receive(:convert).and_raise(error)
        suppress(error.class) { job.perform(document) }
        document.reload
      end

      context "when docling doesn't answer" do
        it "records an unreachable failure at extract" do
          expect(failure_of(document, Docling::Client::Unreachable.new("docling did not respond")))
            .to have_attributes(outcome_stage: "extract", outcome_kind: "unreachable")
        end

        it "keeps the error text for whoever has to fix it" do
          expect(failure_of(document, Docling::Client::Unreachable.new("docling did not respond")).outcome_detail)
            .to include("Docling::Client::Unreachable", "docling did not respond")
        end
      end

      context "when docling refuses the file" do
        it "records a rejected conversion, not an outage" do
          expect(failure_of(document, Docling::Client::ConversionFailed.new("docling returned 422")))
            .to have_attributes(outcome_stage: "extract", outcome_kind: "conversion_rejected")
        end
      end

      context "when nothing is configured to embed with" do
        before { allow(Embeddings::Embed).to receive(:document).and_raise(Embeddings::Embed::NotConfigured) }

        it "blames the embed stage rather than the store it happens inside" do
          suppress(Embeddings::Embed::NotConfigured) { job.perform(document) }
          expect(document.reload).to have_attributes(outcome_stage: "embed", outcome_kind: "not_configured")
        end
      end

      context "when something unclassified goes wrong" do
        it "says so rather than guessing a diagnosis" do
          expect(failure_of(document, ArgumentError.new("nope")))
            .to have_attributes(outcome_stage: "extract", outcome_kind: "internal")
        end
      end

      context "when a later run succeeds" do
        before { document.record_failure!(Ingestion::Outcome.new(stage: "embed", kind: "unreachable", detail: "old")) }

        it "forgets the previous verdict" do
          job.perform(document)
          expect(document.reload)
            .to have_attributes(status: "processed", outcome_stage: nil, outcome_kind: nil, outcome_detail: nil)
        end
      end
    end

    context "when reprocessing a document that already has chunks" do
      before { create(:chunk, document: document, position: 0, content: "stale") }

      it "replaces the prior chunks rather than appending" do
        job.perform(document)
        expect(document.chunks.reload.pluck(:content)).to eq(["Body text."])
      end
    end
  end
end
