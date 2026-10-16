require "rails_helper"

RSpec.describe Views::Pager do
  subject(:component) { described_class.new(page:, action: "/settings/api_calls", params:) }

  let(:result) { component.call }
  let(:params) { {} }
  let(:screen) do
    Struct.new(:older, :newer) do
      def older? = older
      def newer? = newer
      def older_cursor = "OLDER"
      def newer_cursor = "NEWER"
    end
  end
  let(:page) { screen.new(older, newer) }

  describe "#call" do
    context "with rows either side" do
      let(:older) { true }
      let(:newer) { true }

      it "offers both ways" do
        expect(result).to include("← Newer", "Older →")
      end

      it "carries the cursor for each" do
        expect(result).to include("before=NEWER", "after=OLDER")
      end
    end

    context "on the newest screen" do
      let(:older) { true }
      let(:newer) { false }

      it "offers only the way on" do
        expect(result).to include("Older →")
        expect(result).not_to include("Newer")
      end
    end

    context "with everything on one screen" do
      let(:older) { false }
      let(:newer) { false }

      it "renders nothing" do
        expect(result).to eq("")
      end
    end

    context "with filters in effect" do
      let(:older) { true }
      let(:newer) { false }
      let(:params) { { "kind" => "chat", "host" => "tensor" } }

      it "carries them, so paging doesn't drop them" do
        expect(result).to include("kind=chat", "host=tensor", "after=OLDER")
      end
    end
  end
end
