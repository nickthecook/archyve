require 'rails_helper'

RSpec.describe Setting do
  before do
    create(:setting, key: "key1", value: "value1")
    create(:setting, key: "key2", value: "value2")
    create(:setting, key: "key3", value: "value3")
  end

  describe ".get" do
    it "returns the value of a setting" do
      expect(described_class.get("key1")).to eq("value1")
    end

    context "when the setting does not exist" do
      it "returns nil" do
        expect(described_class.get("no_such_key")).to be_nil
      end
    end
  end

  describe ".set" do
    it "sets the setting value" do
      expect { described_class.set("key1", "new_value") }.to(
        change { described_class.get("key1") }.from("value1").to("new_value")
      )
    end

    context "when the setting does not exist" do
      it "returns nil" do
        expect(described_class.set("no_such_key", "abc")).to be_nil
      end

      it "does not create a setting" do
        described_class.set("no_such_key", "abc")
        expect(described_class.find_by(key: "no_such_key")).to be_nil
      end
    end

    it "sets int values correctly" do
      expect { described_class.set("key1", 123) }.to(change { described_class.get("key1") }.from("value1").to(123))
    end

    it "sets hash values correctly" do
      expect { described_class.set("key1", { a: 1, b: 2 }) }.to(
        change { described_class.get("key1") }.from("value1").to({ "a" => 1, "b" => 2 })
      )
    end
  end
end
