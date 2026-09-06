require "rails_helper"

# The transition table these specs pin (one row per (document, collection)):
#
#   from                | to                 | who       | via
#   --------------------|--------------------|-----------|---------
#   absent              | active connector   | connector | .feed!
#   absent              | active manual      | user      | .add
#   active manual       | active connector   | connector | .feed!  (upgrade)
#   active connector    | removed            | connector | .unfeed!
#   active manual       | removed            | user      | .remove
#   removed             | active manual      | user      | .add    (restore, downgrades to manual)
#   removed             | active connector   | connector | .feed!  (restore, re-claims)
#
# Forbidden: active connector -> active manual (no live downgrade); a user
# touching an active connector row.
RSpec.describe CollectionMembership do
  let(:document) { create(:document) }
  let(:collection) { create(:collection) }

  describe ".feed!" do
    subject(:result) { described_class.feed!(document:, collection:) }

    context "when no membership exists" do
      it "creates one row" do
        expect { result }.to change(described_class, :count).by(1)
      end

      it "is an active connector membership" do
        expect(result).to have_attributes(source: "connector", removed_at: nil)
      end
    end

    context "when an active manual membership exists" do
      before { create(:collection_membership, document:, collection:, source: "manual") }

      it "upgrades it in place rather than creating a new row" do
        expect { result }.not_to change(described_class, :count)
      end

      it "becomes a connector membership" do
        expect(result).to be_connector
      end
    end

    context "when a removed membership exists" do
      before { create(:collection_membership, :removed, document:, collection:, source: "manual") }

      it "restores it and claims it as connector" do
        expect(result).to have_attributes(source: "connector", removed_at: nil)
      end
    end
  end

  describe ".unfeed!" do
    subject(:result) { described_class.unfeed!(document:, collection:) }

    context "when an active connector membership exists" do
      let!(:membership) { create(:collection_membership, :connector, document:, collection:) }

      it "tombstones it" do
        expect { result }.to change { membership.reload.active? }.from(true).to(false)
      end
    end

    context "when an active manual membership exists" do
      let!(:membership) { create(:collection_membership, document:, collection:, source: "manual") }

      it "leaves the human's curation untouched" do
        expect { result }.not_to change { membership.reload.active? }
      end

      it "returns nil (nothing to unfeed)" do
        expect(result).to be_nil
      end
    end

    context "when no membership exists" do
      it "returns nil" do
        expect(result).to be_nil
      end
    end
  end

  describe ".add" do
    subject(:result) { described_class.add(document:, collection:) }

    context "when no membership exists" do
      it "creates an active manual membership" do
        expect(result).to have_attributes(source: "manual", removed_at: nil)
      end
    end

    context "when a removed connector membership exists" do
      before { create(:collection_membership, :connector, :removed, document:, collection:) }

      it "restores it, downgrading to manual" do
        expect(result).to have_attributes(source: "manual", removed_at: nil)
      end
    end

    context "when an active connector membership exists" do
      before { create(:collection_membership, :connector, document:, collection:) }

      it "is a no-op that never downgrades" do
        expect(result).to be_connector
      end
    end
  end

  describe ".remove" do
    subject(:result) { described_class.remove(document:, collection:) }

    context "when an active manual membership exists" do
      let!(:membership) { create(:collection_membership, document:, collection:, source: "manual") }

      it "tombstones it" do
        expect { result }.to change { membership.reload.active? }.from(true).to(false)
      end
    end

    context "when an active connector membership exists" do
      before { create(:collection_membership, :connector, document:, collection:) }

      it "refuses — connector rows are retracted at the connector" do
        expect { result }.to raise_error(described_class::NotUserEditableError)
      end
    end

    context "when no active membership exists" do
      it "returns nil" do
        expect(result).to be_nil
      end
    end
  end

  describe "#no_live_downgrade" do
    context "when downgrading an active connector row to manual" do
      subject(:membership) { create(:collection_membership, :connector, document:, collection:) }

      it "is invalid" do
        membership.source = "manual"
        expect(membership).to be_invalid
      end
    end

    context "when restoring a removed connector row as manual" do
      subject(:membership) { create(:collection_membership, :connector, :removed, document:, collection:) }

      it "is valid (the one legitimate downgrade)" do
        membership.assign_attributes(source: "manual", removed_at: nil)
        expect(membership).to be_valid
      end
    end

    context "when upgrading an active manual row to connector" do
      subject(:membership) { create(:collection_membership, document:, collection:, source: "manual") }

      it "is valid" do
        membership.source = "connector"
        expect(membership).to be_valid
      end
    end
  end
end
