require "rails_helper"

RSpec.describe Tools::Admin::InferenceServers do
  subject(:tool) { described_class.new }

  describe "#execute" do
    let(:result) { tool.execute }

    context "with no servers" do
      it { expect(result[:status]).to eq("none") }
    end

    context "with a server that failed its last check" do
      let!(:server) do
        create(:openai_server, name: "vllm", last_checked_at: 5.minutes.ago,
          last_check_status: "failed", last_check_error: "connection refused")
      end

      before { create(:inference_model, inference_server: server, kind: "chat", supports_tools: false, name: "small") }

      it "says what the check found" do
        expect(result[:servers].first[:last_check]).to start_with("failed: connection refused")
      end

      it "lists its models and what they can't do" do
        expect(result[:servers].first[:models]).to eq("small (chat, no tools)")
      end

      it "never reports the server's key" do
        expect(result.to_s).not_to include("sk-test")
      end
    end

    context "with a server never checked" do
      before { create(:inference_server) }

      it "says so" do
        expect(result[:servers].first[:last_check]).to eq("never checked")
      end
    end
  end
end
