require "rails_helper"

RSpec.describe Views::Conversations::ToolCall do
  describe "#call" do
    subject(:panel) { described_class.new(segment:) }

    let(:result) { panel.call }

    context "when the tool has finished" do
      let(:segment) { create(:tool_call_segment) }

      it "says what it checked" do
        expect(result).to include("Checked failed jobs")
      end

      it "shows what came back" do
        expect(result).to include("Docling::Unreachable: refused")
      end
    end

    context "while the tool is running" do
      let(:segment) { create(:tool_call_segment, :running) }

      it "says it is checking" do
        expect(result).to include("Checking failed jobs…")
      end
    end
  end
end
