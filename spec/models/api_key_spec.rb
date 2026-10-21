require "rails_helper"

RSpec.describe ApiKey do
  subject(:api_key) { create(:api_key) }

  describe "#token" do
    let(:result) { api_key.token }

    it "is prefixed so scanners recognise it" do
      expect(result).to start_with("archyve_")
    end

    it "carries 256 bits of URL-safe base64" do
      expect(result.delete_prefix("archyve_")).to match(/\A[A-Za-z0-9_-]{43}\z/)
    end

    it "is not stored" do
      expect(described_class.find(api_key.id).token).to be_nil
    end
  end

  describe "#token_prefix" do
    let(:result) { api_key.token_prefix }

    it "is the start of the token" do
      expect(api_key.token).to start_with(result)
    end
  end

  describe ".authenticate" do
    let(:result) { described_class.authenticate(token) }

    context "with the key's token" do
      let(:token) { api_key.token }

      it { expect(result).to eq(api_key) }
    end

    context "with an unknown token" do
      let(:token) { "archyve_#{'x' * 43}" }

      it { expect(result).to be_nil }
    end

    context "with the stored digest" do
      let(:token) { api_key.token_digest }

      it { expect(result).to be_nil }
    end

    context "with nothing" do
      let(:token) { nil }

      it { expect(result).to be_nil }
    end
  end

  describe "#used!" do
    let(:result) { api_key.used! }

    context "when never used" do
      it "records the time" do
        result
        expect(api_key.reload.last_used_at).to be_within(1.second).of(Time.current)
      end
    end

    context "when used moments ago" do
      let(:earlier) { 10.seconds.ago.floor(6) }

      before { api_key.update_column(:last_used_at, earlier) }

      it "doesn't write again" do
        result
        expect(api_key.reload.last_used_at).to eq(earlier)
      end
    end
  end

  describe "#owner_dormant?" do
    let(:result) { api_key.owner_dormant? }

    before { api_key.user.update_column(:last_signed_in_at, last_signed_in_at) }

    context "when the owner signed in recently" do
      let(:last_signed_in_at) { 2.days.ago }

      it { expect(result).to be(false) }
    end

    context "when the owner hasn't signed in for over 30 days" do
      let(:last_signed_in_at) { 31.days.ago }

      it { expect(result).to be(true) }
    end

    context "when the owner has never signed in" do
      let(:last_signed_in_at) { nil }

      it { expect(result).to be(true) }
    end
  end
end
