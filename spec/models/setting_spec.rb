require "rails_helper"

RSpec.describe Setting do
  # Pinned so the suite doesn't read whoever's shell set them for their own
  # debugging — the round budgets all take their default from the environment.
  before do
    allow(ENV).to receive(:fetch).and_call_original
    %w[SEARCH READ LISTING].each do |budget|
      allow(ENV).to receive(:fetch).with("ARCHYVE_CHAT_MAX_#{budget}_ROUNDS", nil).and_return(nil)
    end
  end

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

  describe "the round budgets" do
    {
      "chat.max_search_rounds" => ["ARCHYVE_CHAT_MAX_SEARCH_ROUNDS", 2],
      "chat.max_read_rounds" => ["ARCHYVE_CHAT_MAX_READ_ROUNDS", 4],
      "chat.max_listing_rounds" => ["ARCHYVE_CHAT_MAX_LISTING_ROUNDS", 4]
    }.each do |key, (variable, default)|
      context "with #{key}" do
        context "when the environment says nothing" do
          it "falls back to its declared default" do
            expect(described_class[key]).to eq(default)
          end
        end

        context "when the environment sets it" do
          before { allow(ENV).to receive(:fetch).with(variable, nil).and_return("7") }

          it "takes its default from there" do
            expect(described_class[key]).to eq(7)
          end
        end
      end
    end
  end

  describe ".chat_max_read_rounds" do
    before do
      allow(ENV).to receive(:fetch).with("ARCHYVE_CHAT_MAX_READ_ROUNDS", nil).and_return(env)
    end

    let(:env) { nil }

    context "when the environment sets something that isn't a count" do
      let(:env) { "lots" }

      it "falls back to the default rather than refusing every read" do
        expect(described_class.chat_max_read_rounds).to eq(4)
      end
    end

    context "when an admin has set it" do
      let(:env) { "9" }

      before { described_class["chat.max_read_rounds"] = 3 }

      it "overrides the environment" do
        expect(described_class.chat_max_read_rounds).to eq(3)
      end
    end
  end

  describe ".clear" do
    context "with a setting that has been changed" do
      before { Setting["chat.default_model_id"] = 42 }

      it "returns it to its default" do
        described_class.clear("chat.default_model_id")
        expect(described_class.chat_default_model_id).to be_nil
      end

      it "removes the row, so nothing records a change that was undone" do
        expect { described_class.clear("chat.default_model_id") }
          .to change { described_class.where(key: "chat.default_model_id").count }.from(1).to(0)
      end
    end

    context "with a setting nobody has touched" do
      it "is a no-op" do
        expect { described_class.clear("chat.default_model_id") }.not_to raise_error
      end
    end

    context "with a key that isn't declared" do
      it "raises, like every other way in" do
        expect { described_class.clear("nope.not.a.setting") }.to raise_error(Setting::UnknownSetting)
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

  describe "an image setting" do
    let(:logo) { Rack::Test::UploadedFile.new(file_fixture("logo.png"), "image/png") }

    context "when nobody has uploaded one" do
      it "is nil" do
        expect(described_class.brand_logo).to be_nil
      end
    end

    context "when one has been uploaded" do
      before { described_class["brand.logo"] = logo }

      it "returns the attachment" do
        expect(described_class.brand_logo.filename.to_s).to eq("logo.png")
      end

      it "purges the file when cleared" do
        expect { described_class.clear("brand.logo") }.to change(ActiveStorage::Attachment, :count).by(-1)
      end
    end

    context "when the file isn't an image" do
      let(:logo) { Rack::Test::UploadedFile.new(file_fixture("sample.md"), "text/markdown") }

      it "refuses it" do
        expect { described_class["brand.logo"] = logo }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
