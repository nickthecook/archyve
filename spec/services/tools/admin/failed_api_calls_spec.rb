require "rails_helper"

RSpec.describe Tools::Admin::FailedApiCalls do
  subject(:tool) { described_class.new }

  describe "#execute" do
    let(:result) { tool.execute }

    context "with only successful calls" do
      before { create(:api_call) }

      it { expect(result[:calls]).to eq("none recorded") }
    end

    context "with a call nothing answered" do
      before { create(:api_call, :refused) }

      it "names why" do
        expect(result[:calls].first).to include(outcome: "Connection refused")
      end

      it "keeps the error" do
        expect(result[:calls].first[:error]).to start_with("Failed to open TCP connection")
      end
    end

    context "with a call that got an error status" do
      before { create(:api_call, response_code: 500, url: "http://gpu:8000/v1/chat?key=secret") }

      it "reports the status" do
        expect(result[:calls].first).to include(outcome: "HTTP 500")
      end

      it "drops the query string" do
        expect(result[:calls].first[:request]).to eq("POST gpu/v1/chat")
      end

      it "reports no bodies or headers" do
        expect(result.to_s).not_to include("An answer.", "llama3.2", "content-type")
      end
    end
  end
end
