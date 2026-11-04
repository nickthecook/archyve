require "rails_helper"

RSpec.describe Toolsets::Archive do
  subject(:toolset) { described_class.new(conversation) }

  let(:conversation) { create(:conversation) }

  describe "#instructions" do
    subject(:instructions) { toolset.instructions }

    context "when the conversation draws on the whole archive" do
      it "names the scope" do
        expect(instructions).to start_with("This conversation is drawing on: your whole archive.")
      end

      it "tells the model how to cite" do
        expect(instructions).to include("cite it by writing the handle in square brackets")
      end
    end

    context "when the conversation draws on one collection" do
      let(:conversation) { create(:conversation, :scoped, collection:, user: create(:user, :admin)) }
      let(:collection) { create(:collection, name: "Security Handbook") }

      it "names that collection" do
        expect(instructions).to start_with("This conversation is drawing on: Security Handbook.")
      end
    end

    context "when the conversation draws on no collections" do
      let(:conversation) { create(:conversation, :no_collections) }

      it "says the archive is not in play" do
        expect(instructions).to start_with("This conversation is not drawing on the archive")
      end

      it "mentions no tools" do
        expect(instructions).not_to include("search_archive")
      end
    end
  end

  describe "#tools" do
    subject(:tools) { toolset.tools(observer: nil) }

    context "when the conversation draws on the archive" do
      it "offers searching, reading and listing" do
        expect(tools.map(&:class)).to eq([Tools::Search, Tools::Read, Tools::ListCollections, Tools::ListDocuments])
      end
    end

    context "when the conversation draws on no collections" do
      let(:conversation) { create(:conversation, :no_collections) }

      it "offers none" do
        expect(tools).to be_empty
      end
    end
  end
end
