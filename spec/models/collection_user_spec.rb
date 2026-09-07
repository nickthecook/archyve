require "rails_helper"

RSpec.describe CollectionUser, type: :model do
  describe "uniqueness" do
    subject(:grant) { build(:collection_user, collection:, user:) }

    let(:collection) { create(:collection) }
    let(:user) { create(:user, :operator) }
    let(:result) { grant.valid? }

    context "when the person already has a grant on the collection" do
      before { create(:collection_user, collection:, user:) }

      it "is invalid, because access is changed by editing the grant" do
        expect(result).to be(false)
      end
    end

    context "when their existing grant is on a different collection" do
      before { create(:collection_user, collection: create(:collection), user:) }

      it "is valid" do
        expect(result).to be(true)
      end
    end
  end
end
