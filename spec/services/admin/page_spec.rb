require "rails_helper"

RSpec.describe Admin::Page do
  subject(:page) { described_class.of(ApiCall.all, per: 2) }

  # Created oldest-first so the newest is unambiguous.
  let!(:oldest) { create(:api_call, created_at: 3.hours.ago) }
  let!(:middle) { create(:api_call, created_at: 2.hours.ago) }
  let!(:newest) { create(:api_call, created_at: 1.hour.ago) }

  describe "#records" do
    it "starts at the newest" do
      expect(page.records).to eq([newest, middle])
    end

    it "says there are older rows and no newer ones" do
      expect(page.older?).to be(true)
      expect(page.newer?).to be(false)
    end
  end

  describe "paging older" do
    subject(:older) { described_class.of(ApiCall.all, per: 2, after: page.older_cursor) }

    it "carries on where the last screen stopped" do
      expect(older.records).to eq([oldest])
    end

    it "offers the way back and nothing further on" do
      expect(older.newer?).to be(true)
      expect(older.older?).to be(false)
    end

    it "comes back to the same first screen" do
      back = described_class.of(ApiCall.all, per: 2, before: older.newer_cursor)
      expect(back.records).to eq([newest, middle])
    end
  end

  # A row inserted between two screens is exactly what offset paging gets wrong.
  context "when a row lands while the reader is on the first screen" do
    it "doesn't repeat a row already shown" do
      cursor = page.older_cursor
      create(:api_call, created_at: Time.current)

      expect(described_class.of(ApiCall.all, per: 2, after: cursor).records).to eq([oldest])
    end
  end

  context "with a cursor that no longer decodes" do
    subject(:page) { described_class.of(ApiCall.all, per: 2, after: "not-a-cursor") }

    it "falls back to the newest screen rather than failing" do
      expect(page.records).to eq([newest, middle])
    end
  end

  context "with an ordering of its own" do
    subject(:page) { described_class.of(ApiCall.all, per: 2, order: { created_at: :asc }) }

    it "pages that way instead" do
      expect(page.records).to eq([oldest, middle])
    end
  end

  # The three above are chat, the factory's default.
  context "with a relation that is already filtered" do
    let!(:discovery) { create(:api_call, kind: "discovery", created_at: Time.current) }

    it "pages only what the filter left" do
      expect(described_class.of(ApiCall.of_kind("discovery"), per: 2).records).to eq([discovery])
    end
  end
end
