require "rails_helper"

RSpec.describe Setting do
  describe ".[]" do
    subject(:result) { described_class["chat.result_limit"] }

    context "when nobody has changed it" do
      it "returns the declared default" do
        expect(result).to eq(6)
      end

      it "does not write a row to say so" do
        result
        expect(described_class.count).to eq(0)
      end
    end

    context "when it has been changed" do
      before { described_class["chat.result_limit"] = 12 }

      it "returns the stored value, cast to its declared type" do
        expect(result).to eq(12)
      end
    end

    context "when the key isn't declared" do
      subject(:result) { described_class["chat.nonsense"] }

      it "raises rather than returning nil" do
        expect { result }.to raise_error(described_class::UnknownSetting, /chat.nonsense/)
      end
    end
  end

  describe ".chat_instance_purpose" do
    context "when nobody has set it" do
      it "defaults to blank" do
        expect(described_class.chat_instance_purpose).to eq("")
      end
    end

    context "when an admin has set it" do
      before { described_class["chat.instance_purpose"] = "Answer questions for my family." }

      it "returns it" do
        expect(described_class.chat_instance_purpose).to eq("Answer questions for my family.")
      end
    end
  end

  describe ".[]=" do
    context "when setting the same key twice" do
      before do
        described_class["chat.result_limit"] = 8
        described_class["chat.result_limit"] = 9
      end

      it "keeps one row" do
        expect(described_class.count).to eq(1)
      end

      it "keeps the last value" do
        expect(described_class["chat.result_limit"]).to eq(9)
      end
    end

    context "when the key isn't declared" do
      it "raises rather than storing it" do
        expect { described_class["nope"] = 1 }.to raise_error(described_class::UnknownSetting)
      end
    end
  end
end
