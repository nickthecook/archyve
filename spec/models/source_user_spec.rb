require "rails_helper"

RSpec.describe SourceUser, type: :model do
  subject(:grant) { build(:source_user, source:, user:, role:) }

  let(:source) { create(:source) }
  let(:user) { create(:user, :curator) }
  let(:result) { grant.valid? }

  describe "role" do
    # `visitor` means "may draw on this source", not "may read it" — enough to
    # feed it into a collection you administer, and nothing more. It is what
    # lets IT own a source's credentials while a team decides what their
    # collection pulls from.
    context "when it is `visitor`" do
      let(:role) { "visitor" }

      it "is valid" do
        expect(result).to be(true)
      end
    end

    context "when it is `curator`" do
      let(:role) { "curator" }

      it "is valid" do
        expect(result).to be(true)
      end
    end

    context "when it is `admin`" do
      let(:role) { "admin" }

      it "is valid" do
        expect(result).to be(true)
      end
    end
  end
end
