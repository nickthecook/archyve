require "rails_helper"

RSpec.describe ApiCall do
  describe ".recording?" do
    subject(:recording) { described_class.recording? }

    context "with nothing set" do
      it "is off, so a deployment that never asked for this records nothing" do
        expect(recording).to be(false)
      end
    end

    context "when a setting row turns it on" do
      before { Setting["debug.record_api_calls"] = true }

      it { is_expected.to be(true) }
    end

    context "when a setting row turns it back off" do
      before { Setting["debug.record_api_calls"] = false }

      it { is_expected.to be(false) }
    end

    context "when the settings table cannot be read" do
      before { allow(Setting).to receive(:record_api_calls?).and_raise(ActiveRecord::StatementInvalid, "no table") }

      it "is off rather than raising inside the call it observes" do
        expect(recording).to be(false)
      end
    end
  end

  describe ".expired" do
    subject(:expired) { described_class.expired }

    let(:attributes) { { service_name: "vllm", kind: "chat", http_method: "post", url: "http://llm.test" } }
    let!(:old) { described_class.create!(**attributes, created_at: (described_class::RETENTION + 1.hour).ago) }

    context "with a row inside the retention window" do
      let!(:fresh) { described_class.create!(**attributes) }

      it "excludes it" do
        expect(expired).not_to include(fresh)
      end

      it "includes the expired one" do
        expect(expired).to include(old)
      end
    end
  end
end
