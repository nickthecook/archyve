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
    subject(:agent) { create(:agent, access_mode:, creator:) }

    let(:result) { agent.usable_by?(user) }
    let(:access_mode) { "everyone" }
    let(:creator) { nil }
    let(:user) { create(:user) }

    context "when everyone may use it" do
      it { expect(result).to be(true) }

      context "with a toolset whose floor is above the user" do
        before { allow(Toolsets::Archive).to receive(:role_floor).and_return(:curator) }

        it { expect(result).to be(false) }
      end

      context "with a toolset whose floor the user meets" do
        let(:user) { create(:user, :curator) }

        before { allow(Toolsets::Archive).to receive(:role_floor).and_return(:curator) }

        it { expect(result).to be(true) }
      end
    end

    context "when it is granted" do
      let(:access_mode) { "granted" }

      context "and the user holds no grant" do
        it { expect(result).to be(false) }
      end

      context "and the user holds a grant" do
        before { create(:agent_user, agent:, user:) }

        it { expect(result).to be(true) }
      end

      context "and the user is an admin with no grant" do
        let(:user) { create(:user, :admin) }

        it { expect(result).to be(true) }
      end

      # The floor is worked out at chat time, so adding an admin-only toolset
      # makes a lower-role grant inactive rather than widening it.
      context "and the user holds a grant below the toolset floor" do
        before do
          create(:agent_user, agent:, user:, access: "manager")
          allow(Toolsets::Archive).to receive(:role_floor).and_return(:admin)
        end

        it { expect(result).to be(false) }
      end
    end

    context "when only its creator may use it" do
      let(:access_mode) { "creator_only" }
      let(:creator) { create(:user) }

      context "and the user is the creator" do
        let(:user) { creator }

        it { expect(result).to be(true) }
      end

      context "and the user is someone else" do
        it { expect(result).to be(false) }
      end

      # The one place "admins can do everything" doesn't hold.
      context "and the user is an admin" do
        let(:user) { create(:user, :admin) }

        it { expect(result).to be(false) }
      end

      context "and the user holds a grant anyway" do
        before { create(:agent_user, agent:, user:, access: "manager") }

        it { expect(result).to be(false) }
      end

      context "and the creator's account has been deleted" do
        let(:user) { creator }

        before do
          agent
          create(:user, :admin)
          creator.destroy!
        end

        it "keeps the agent without a creator" do
          expect(agent.reload.creator).to be_nil
        end
      end
    end
  end

  describe "its slug" do
    subject(:agent) { create(:agent, slug: nil, name:) }

    context "with an ordinary name" do
      let(:name) { "Policy Bot" }

      it { expect(agent.slug).to eq("policy-bot") }
    end

    context "with a name another agent's slug already has" do
      let(:name) { "Archivist" }

      it "numbers it" do
        expect(agent.slug).to eq("archivist-2")
      end
    end

    # /settings/agents/new is the form, not an agent.
    context "with a name that would collide with a route" do
      let(:name) { "New" }

      it { expect(agent.slug).to eq("new-agent") }
    end
  end

  describe ".default_chat" do
    let(:result) { described_class.default_chat }

    context "when nothing has been chosen" do
      it { expect(result).to eq(described_class.archivist) }
    end

    context "when an agent everyone can use has been chosen" do
      let!(:chosen) { create(:agent, slug: "policy-bot") }

      before { Setting["chat.default_agent"] = "policy-bot" }

      it { expect(result).to eq(chosen) }
    end

    context "when the chosen agent has since become granted" do
      before do
        create(:agent, slug: "policy-bot", access_mode: "granted")
        Setting["chat.default_agent"] = "policy-bot"
      end

      it "falls back to Archivist" do
        expect(result).to eq(described_class.archivist)
      end
    end

    context "when the chosen agent no longer exists" do
      before { Setting["chat.default_agent"] = "gone" }

      it { expect(result).to eq(described_class.archivist) }
    end
  end

  describe ".choosable_by" do
    let(:result) { described_class.choosable_by(user) }
    let(:user) { create(:user, :admin) }

    before { create(:agent, name: "Someone's private bot", access_mode: "creator_only", creator: create(:user)) }

    it "offers what they can use, but not Admin Support" do
      expect(result.map(&:name)).to eq(["Archivist"])
    end
  end

  describe "#duplicate" do
    subject(:copy) { original.duplicate(by: user) }

    let(:original) { create(:agent, name: "Policy bot", collection_mode: "fixed", access_mode: "everyone") }
    let(:user) { create(:user, :admin) }
    let(:collection) { create(:collection) }

    before { create(:agent_collection, agent: original, collection:) }

    it "names it as a copy" do
      expect(copy.name).to eq("Policy bot (copy)")
    end

    it "keeps its collections" do
      expect(copy.collection_ids).to eq([collection.id])
    end

    it "starts private to whoever copied it" do
      expect(copy).to have_attributes(access_mode: "creator_only", creator: user)
    end

    it "saves" do
      expect(copy.save).to be(true)
    end
  end

  describe "#removal_refusal" do
    subject(:agent) { create(:agent) }

    context "when nothing uses it" do
      it { expect(agent.removal_refusal).to be_nil }
    end

    context "when a conversation used it" do
      before { create(:conversation, agent:) }

      it { expect(agent.removal_refusal).to include("1 conversation") }
    end

    context "when it is built in" do
      subject(:agent) { described_class.archivist }

      it { expect(agent.removal_refusal).to include("Built-in") }
    end
  end

  describe "validation of a creator-only agent" do
    subject(:agent) { build(:agent, access_mode: "creator_only", creator: nil) }

    it "needs a creator" do
      expect(agent).not_to be_valid
    end
  end

  describe "#narrowable?" do
    subject(:agent) { build(:agent, toolset_keys:, collection_mode:) }

    let(:toolset_keys) { ["archive"] }
    let(:collection_mode) { "user" }

    context "when it draws on what the user can read" do
      it { is_expected.to be_narrowable }
    end

    context "when it has a fixed set" do
      let(:collection_mode) { "fixed" }

      it { is_expected.not_to be_narrowable }
    end

    context "when it doesn't search the archive" do
      let(:toolset_keys) { ["admin_support"] }

      it { is_expected.not_to be_narrowable }
    end
  end

  describe "a collection in its fixed set" do
    let(:agent) { create(:agent, collection_mode: "fixed") }
    let(:collection) { create(:collection) }

    before { create(:agent_collection, agent:, collection:) }

    context "when the collection is deleted" do
      before { collection.destroy! }

      it "leaves the set" do
        expect(agent.collections.reload).to be_empty
      end
    end
  end
end
