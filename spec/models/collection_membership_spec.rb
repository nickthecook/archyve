require "rails_helper"

# The transition table these specs pin (one row per (document, collection)):
#
#   from                | to                 | who       | via
#   --------------------|--------------------|-----------|---------
#   absent              | active source   | source | .feed!
#   absent              | active manual      | user      | .add
#   active manual       | active source   | source | .feed!  (upgrade)
#   active source    | removed            | source | .unfeed!
#   active manual       | removed            | user      | .remove
#   removed             | active manual      | user      | .add    (restore, downgrades to manual)
#   removed             | active source   | source | .feed!  (restore, re-claims)
#
# Forbidden: active source -> active manual (no live downgrade); a user
# touching an active source row.
RSpec.describe CollectionMembership do
  let(:document) { create(:document) }
  let(:collection) { create(:collection) }

  describe ".feed!" do
    subject(:result) { described_class.feed!(document:, collection:) }

    context "when no membership exists" do
      it "creates one row" do
        expect { result }.to change(described_class, :count).by(1)
      end

      it "is an active feed membership" do
        expect(result).to have_attributes(origin: "feed", removed_at: nil)
      end
    end

    context "when an active manual membership exists" do
      before { create(:collection_membership, document:, collection:, origin: "manual") }

      it "upgrades it in place rather than creating a new row" do
        expect { result }.not_to change(described_class, :count)
      end

      it "becomes a feed membership" do
        expect(result).to be_feed
      end
    end

    context "when a removed membership exists" do
      before { create(:collection_membership, :removed, document:, collection:, origin: "manual") }

      it "restores it and claims it as source" do
        expect(result).to have_attributes(origin: "feed", removed_at: nil)
      end
    end
  end

  describe ".unfeed!" do
    subject(:result) { described_class.unfeed!(document:, collection:) }

    context "when an active feed membership exists" do
      let!(:membership) { create(:collection_membership, :feed, document:, collection:) }

      it "tombstones it" do
        expect { result }.to change { membership.reload.active? }.from(true).to(false)
      end
    end

    context "when an active manual membership exists" do
      let!(:membership) { create(:collection_membership, document:, collection:, origin: "manual") }

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
        expect(result).to have_attributes(origin: "manual", removed_at: nil)
      end
    end

    context "when a removed feed membership exists" do
      before { create(:collection_membership, :feed, :removed, document:, collection:) }

      it "restores it, downgrading to manual" do
        expect(result).to have_attributes(origin: "manual", removed_at: nil)
      end
    end

    context "when an active feed membership exists" do
      before { create(:collection_membership, :feed, document:, collection:) }

      it "is a no-op that never downgrades" do
        expect(result).to be_feed
      end
    end
  end

  describe ".remove" do
    subject(:result) { described_class.remove(document:, collection:) }

    context "when an active manual membership exists" do
      let!(:membership) { create(:collection_membership, document:, collection:, origin: "manual") }

      it "tombstones it" do
        expect { result }.to change { membership.reload.active? }.from(true).to(false)
      end
    end

    context "when an active feed membership exists" do
      before { create(:collection_membership, :feed, document:, collection:) }

      it "refuses — source rows are retracted at the source" do
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
    context "when downgrading an active source row to manual" do
      subject(:membership) { create(:collection_membership, :feed, document:, collection:) }

      it "is invalid" do
        membership.origin = "manual"
        expect(membership).to be_invalid
      end
    end

    context "when restoring a removed source row as manual" do
      subject(:membership) { create(:collection_membership, :feed, :removed, document:, collection:) }

      it "is valid (the one legitimate downgrade)" do
        membership.assign_attributes(origin: "manual", removed_at: nil)
        expect(membership).to be_valid
      end
    end

    context "when upgrading an active manual row to source" do
      subject(:membership) { create(:collection_membership, document:, collection:, origin: "manual") }

      it "is valid" do
        membership.origin = "feed"
        expect(membership).to be_valid
      end
    end
  end
end
