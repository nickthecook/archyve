require "rails_helper"

RSpec.describe Agent do
  describe ".seed_built_ins!" do
    subject(:seed) { described_class.seed_built_ins! }

    let(:archivist) { described_class.archivist }

    it "creates every built-in once" do
      expect { seed }.not_to change(described_class, :count)
    end

    it "marks them built in" do
      seed
      expect(archivist).to be_built_in
    end

    it "gives Archivist the archive" do
      seed
      expect(archivist.toolsets).to eq([Toolsets::Archive])
    end

    context "when a built-in's prompt has drifted from the code" do
      before { described_class.archivist.update!(prompt: "Something an admin typed.") }

      it "rewrites it" do
        seed
        expect(archivist.prompt).to eq(described_class::BUILT_INS.dig("archivist", :prompt))
      end
    end

    context "when a built-in is missing" do
      before { described_class.archivist.destroy! }

      it "recreates it" do
        expect { seed }.to change(described_class, :count).by(1)
      end
    end
  end

  describe "validation" do
    subject(:agent) { build(:agent, toolset_keys:) }

    context "when every toolset exists" do
      let(:toolset_keys) { ["archive"] }

      it { is_expected.to be_valid }
    end

    context "when a toolset doesn't exist" do
      let(:toolset_keys) { ["archive", "shell"] }

      it "names it" do
        agent.validate
        expect(agent.errors[:toolset_keys]).to eq(["names unknown toolsets: shell"])
      end
    end
  end

  describe "#role_floor" do
    subject(:agent) { build(:agent, toolset_keys:) }

    let(:result) { agent.role_floor }

    context "when it has no toolsets" do
      let(:toolset_keys) { [] }

      it { expect(result).to eq(:visitor) }
    end

    context "when it has the archive" do
      let(:toolset_keys) { ["archive"] }

      it { expect(result).to eq(:visitor) }
    end

    context "when a toolset needs an admin" do
      let(:toolset_keys) { ["archive"] }

      before { allow(Toolsets::Archive).to receive(:role_floor).and_return(:admin) }

      it { expect(result).to eq(:admin) }
    end
  end

  describe "#usable_by?" do
    subject(:agent) { build(:agent) }

    let(:result) { agent.usable_by?(user) }

    before { allow(Toolsets::Archive).to receive(:role_floor).and_return(:curator) }

    context "when the user is below the floor" do
      let(:user) { build(:user) }

      it { expect(result).to be(false) }
    end

    context "when the user is at the floor" do
      let(:user) { build(:user, :curator) }

      it { expect(result).to be(true) }
    end

    context "when the user is above the floor" do
      let(:user) { build(:user, :admin) }

      it { expect(result).to be(true) }
    end
  end
end
