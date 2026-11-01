require "rails_helper"

RSpec.describe SourceUser, type: :model do
  subject(:grant) { build(:source_user, source:, user:, access:) }

  let(:source) { create(:source) }
  let(:user) { create(:user, :curator) }
  let(:result) { grant.valid? }

  describe "access" do
    # `accessor` means "may draw on this source", not "may read it" — enough to
    # feed it into a collection you manage, and nothing more. It is what lets IT
    # own a source's credentials while a team decides what their collection
    # pulls from.
    context "when it is `accessor`" do
      let(:access) { "accessor" }

      it "is valid" do
        expect(result).to be(true)
      end
    end

    context "when it is `editor`" do
      let(:access) { "editor" }

      it "is valid" do
        expect(result).to be(true)
      end
    end

    context "when it is `manager`" do
      let(:access) { "manager" }

      it "is valid" do
        expect(result).to be(true)
      end
    end
  end
end
