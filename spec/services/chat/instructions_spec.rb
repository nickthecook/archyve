require "rails_helper"

RSpec.describe Chat::Instructions do
  describe ".for" do
    subject(:prompt) { described_class.for(conversation) }

    let(:conversation) { create(:conversation, agent:) }
    let(:agent) { create(:agent, prompt: "You are the test agent.") }
    let(:archive_instructions) { Toolsets::Archive.new(conversation).instructions }

    it "opens with the agent's prompt" do
      expect(prompt).to start_with("You are the test agent.\n\n")
    end

    it "follows it with the archive toolset's instructions" do
      expect(prompt).to include("\n\n#{archive_instructions}")
    end

    context "when the instance has a purpose" do
      before { Setting["chat.instance_purpose"] = "Answering questions about the family archive." }

      it "ends with it" do
        expect(prompt).to end_with(
          "\n\nThis instance's purpose, set by its administrator: Answering questions about the family archive."
        )
      end
    end

    context "when the instance has no purpose" do
      before { Setting["chat.instance_purpose"] = "" }

      it "ends with the toolset's instructions" do
        expect(prompt).to end_with(archive_instructions)
      end
    end

    context "when the agent has no prompt" do
      let(:agent) { create(:agent, prompt: "") }

      it "starts with the toolset's instructions" do
        expect(prompt).to start_with(archive_instructions)
      end
    end

    context "when the agent has no toolsets" do
      let(:agent) { create(:agent, prompt: "You are the test agent.", toolset_keys: []) }

      before { Setting["chat.instance_purpose"] = "" }

      it "is the agent's prompt alone" do
        expect(prompt).to eq("You are the test agent.")
      end
    end
  end
end
