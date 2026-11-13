require "rails_helper"

RSpec.describe Collection do
  describe "access scopes" do
    let(:user) { create(:user, :curator) }
    let!(:collection) { create(:collection) }
    let(:group) { create(:group) }

    before { group.users << user }

    context "when the user's group holds an accessor grant" do
      before { create(:collection_group, collection:, group:) }

      it "is readable" do
        expect(described_class.readable_by(user)).to include(collection)
      end

      it "is not manageable" do
        expect(described_class.manageable_by(user)).not_to include(collection)
      end
    end

    context "when the user's group holds a manager grant" do
      before { create(:collection_group, :manager, collection:, group:) }

      it "is administrable" do
        expect(described_class.administrable_by(user)).to include(collection)
      end
    end

    context "when a group the user isn't in holds a grant" do
      before { create(:collection_group, :manager, collection:) }

      it "is not readable" do
        expect(described_class.readable_by(user)).not_to include(collection)
      end
    end
  end

  describe "#set_slug" do
    subject(:collection) { described_class.create!(name:, slug:) }

    let(:slug) { nil }

    context "when no slug is given" do
      let(:name) { "Design Docs" }

      it "derives a parameterized slug from the name" do
        expect(collection.slug).to eq("design-docs")
      end
    end

    context "when a slug is given" do
      let(:name) { "Design Docs" }
      let(:slug) { "custom-slug" }

      it "keeps the given slug rather than deriving one" do
        expect(collection.slug).to eq("custom-slug")
      end
    end

    context "when the name has mixed case and punctuation" do
      let(:name) { "Q3 Reports & Notes!" }

      it "parameterizes it" do
        expect(collection.slug).to eq("q3-reports-notes")
      end
    end
  end

  describe "#to_param" do
    subject(:collection) { create(:collection, name: "Design Docs") }

    it "is the slug, so URLs address the collection by slug" do
      expect(collection.to_param).to eq("design-docs")
    end
  end

  describe "validations" do
    subject(:collection) { build(:collection, name:) }

    context "when the name is blank" do
      let(:name) { nil }

      it "is invalid" do
        expect(collection).to be_invalid
      end
    end

    context "when the name is present" do
      let(:name) { "Handbook" }

      it "is valid" do
        expect(collection).to be_valid
      end
    end

    context "when another collection already has the slug" do
      let(:name) { "Handbook" }

      before { create(:collection, name: "Handbook") }

      it "is invalid (slug uniqueness)" do
        expect(collection).to be_invalid
      end
    end
  end

  describe "#documents" do
    subject(:documents) { collection.documents }

    let(:collection) { create(:collection) }
    let(:document) { create(:document) }

    context "when the document has an active manual membership" do
      before { create(:collection_membership, collection:, document:, origin: "manual") }

      it "is included" do
        expect(documents).to include(document)
      end
    end

    context "when the document has an active feed membership" do
      before { create(:collection_membership, :feed, collection:, document:) }

      it "is included" do
        expect(documents).to include(document)
      end
    end

    context "when the document's membership is removed" do
      before { create(:collection_membership, :removed, collection:, document:) }

      it "is excluded" do
        expect(documents).not_to include(document)
      end
    end

    context "when the document has no membership in this collection" do
      before { document }

      it "is excluded" do
        expect(documents).not_to include(document)
      end
    end
  end
end
