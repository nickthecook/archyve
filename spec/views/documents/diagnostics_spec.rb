require "rails_helper"

# Rendered two ways: inside a request, and from the Document model during a
# broadcast — where there is no request, no routes and no signed-in user. These
# examples are the second way, since that is the one nothing else would catch.
RSpec.describe Views::Documents::Diagnostics do
  subject(:result) { described_class.new(document:).call }

  let(:document) { create(:document, status: "failed", **facts) }

  context "when the pipeline recorded what went wrong" do
    let(:facts) do
      {
        failure_stage: "embed",
        failure_kind: "unreachable",
        failure_detail: "Faraday::ConnectionFailed: tensor:11434"
      }
    end

    it "names where the pipeline stopped and what stopped it" do
      expect(result).to include("embed · unreachable")
    end

    it "shows the raw error, which is the thing the logs weren't giving anyone" do
      expect(result).to include("Faraday::ConnectionFailed: tensor:11434")
    end
  end

  # Every document that failed before any of this existed, which in production
  # is the one being looked at.
  context "when the document failed before there were facts to record" do
    let(:facts) { {} }

    it "says there is no diagnosis rather than implying an empty one" do
      expect(result).to include("no diagnosis was recorded")
    end
  end

  context "when nothing has gone wrong" do
    let(:document) { create(:document, status: "processed") }

    # Somewhere for the broadcast and the poll to land, so a document that
    # fails while someone is watching has a place to put the news.
    it "still renders its region" do
      expect(result).to include(described_class.dom_id(document))
    end

    it "puts nothing in it" do
      expect(result).not_to include("no diagnosis")
    end
  end
end
