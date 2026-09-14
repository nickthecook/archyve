require "rails_helper"

RSpec.describe Docling::Client do
  subject(:convert) { described_class.new.convert(StringIO.new("bytes"), filename: "manual.pdf") }

  let(:stubs) { Faraday::Adapter::Test::Stubs.new }

  # A real connection with the real middleware, stubbed at the adapter: the
  # behaviour under test is how a Faraday error becomes one of ours, and
  # stubbing the client's own HTTP call would skip exactly that.
  let(:connection) do
    Faraday.new do |f|
      f.request :multipart
      f.response :raise_error
      f.adapter :test, stubs
    end
  end

  before { allow(Http).to receive(:connection).and_return(connection) }

  # OCR is the expensive half of a conversion, so what we ask for has to be
  # exactly what the caller chose — not docling's default standing in for it.
  describe "the OCR choice" do
    subject(:convert) { described_class.new.convert(StringIO.new("bytes"), filename: "manual.pdf", ocr: ocr) }

    let(:connection) { instance_double(Faraday::Connection, post: response) }
    let(:response) { instance_double(Faraday::Response, body: { "status" => "success" }.to_json) }

    context "when the caller wants OCR" do
      let(:ocr) { true }

      it "asks for it" do
        convert
        expect(connection).to have_received(:post).with(anything, hash_including("do_ocr" => "true"))
      end
    end

    context "when the caller doesn't" do
      let(:ocr) { false }

      it "says so rather than leaving docling to its default" do
        convert
        expect(connection).to have_received(:post).with(anything, hash_including("do_ocr" => "false"))
      end
    end
  end

  describe "#convert" do
    context "when docling converts the file" do
      before do
        stubs.post(described_class::CONVERT_PATH) do
          [200, {}, { "status" => "success", "document" => { "json_content" => { "texts" => [] } } }.to_json]
        end
      end

      it "returns the result" do
        expect(convert).to be_a(Docling::Result)
      end
    end

    # The distinction the document page turns into two different sentences, so
    # each of these is about which one the operator ends up reading.
    context "when nothing answers" do
      before { stubs.post(described_class::CONVERT_PATH) { raise Faraday::ConnectionFailed, "refused" } }

      it "is unreachable" do
        expect { convert }.to raise_error(described_class::Unreachable, /did not respond/)
      end
    end

    context "when docling breaks on the file" do
      before { stubs.post(described_class::CONVERT_PATH) { [500, {}, "traceback: boom"] } }

      it "is unreachable — a 5xx is theirs to fix, not the uploader's" do
        expect { convert }.to raise_error(described_class::Unreachable)
      end

      it "keeps the body, which is where docling says why" do
        expect { convert }.to raise_error(/traceback: boom/)
      end
    end

    context "when docling refuses the file" do
      before { stubs.post(described_class::CONVERT_PATH) { [422, {}, "unsupported format"] } }

      it "blames the document" do
        expect { convert }.to raise_error(described_class::ConversionFailed, /422/)
      end
    end

    # Docling reports a per-file failure in the envelope of a 200, so a success
    # status code is not a successful conversion.
    context "when docling reports a failure in a 200" do
      before do
        stubs.post(described_class::CONVERT_PATH) do
          [200, {}, { "status" => "failure", "errors" => ["could not parse page 1"] }.to_json]
        end
      end

      it "is a rejected conversion" do
        expect { convert }.to raise_error(described_class::ConversionFailed, /could not parse page 1/)
      end
    end
  end
end
