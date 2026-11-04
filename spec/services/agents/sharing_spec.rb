require "rails_helper"

RSpec.describe Agents::Sharing do
  subject(:sharing) { described_class.new(agent, by:) }

  let(:by) { curator }
  let(:curator) { create(:user, :curator) }
  let(:managed) { create(:collection, name: "Handbook") }
  let(:unmanaged) { create(:collection, name: "Board minutes") }

  before do
    create(:collection_user, :manager, collection: managed, user: curator)
    create(:collection_user, collection: unmanaged, user: curator)
  end

  describe "#refusal" do
    let(:result) { sharing.refusal(access_mode:, collection_mode:, collection_ids:) }
    let(:access_mode) { "everyone" }
    let(:collection_mode) { "fixed" }

    context "with a new agent" do
      let(:agent) { Agent.new }

      context "sharing collections they manage" do
        let(:collection_ids) { [managed.id] }

        it { expect(result).to be_nil }
      end

      context "sharing one they only read" do
        let(:collection_ids) { [managed.id, unmanaged.id] }

        it "names it" do
          expect(result).to include("you don't manage Board minutes")
        end
      end

      context "kept to themselves" do
        let(:access_mode) { "creator_only" }
        let(:collection_ids) { [unmanaged.id] }

        it { expect(result).to be_nil }
      end

      context "drawing on what each person can read" do
        let(:collection_mode) { "user" }
        let(:collection_ids) { [unmanaged.id] }

        it { expect(result).to be_nil }
      end
    end

    context "with a shared agent that already holds a collection they don't manage" do
      let(:agent) { create(:agent, collection_mode: "fixed", access_mode: "everyone") }

      before { create(:agent_collection, agent:, collection: unmanaged) }

      context "adding one they manage" do
        let(:collection_ids) { [unmanaged.id, managed.id] }

        it "only checks what was added" do
          expect(result).to be_nil
        end
      end

      context "adding another they don't manage" do
        let(:other) { create(:collection, name: "Payroll") }
        let(:collection_ids) { [unmanaged.id, other.id] }

        it "names only the new one" do
          expect(result).to include("you don't manage Payroll.")
        end
      end
    end

    context "with a creator-only agent being shared" do
      let(:agent) { create(:agent, collection_mode: "fixed", access_mode: "creator_only", creator: curator) }
      let(:collection_ids) { [unmanaged.id] }

      before { create(:agent_collection, agent:, collection: unmanaged) }

      it "checks every collection it holds, not only new ones" do
        expect(result).to include("Board minutes")
      end
    end

    context "with an agent switching from what each person can read to a fixed set" do
      let(:agent) { create(:agent, collection_mode: "user", access_mode: "everyone") }
      let(:collection_ids) { [unmanaged.id] }

      before { create(:agent_collection, agent:, collection: unmanaged) }

      it "checks the collections it already had" do
        expect(result).to include("Board minutes")
      end
    end

    context "when an admin shares anything" do
      let(:agent) { Agent.new }
      let(:collection_ids) { [unmanaged.id] }
      let(:by) { create(:user, :admin) }

      it { expect(result).to be_nil }
    end
  end
end
