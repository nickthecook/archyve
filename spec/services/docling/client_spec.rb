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
