require "rails_helper"

RSpec.describe Endpoints::Bamboohr do
  subject(:endpoint) { build(:bamboohr_endpoint, base_url:, api_key: "s3cret") }

  let(:base_url) { "https://acme.bamboohr.com" }

  describe "#auth_headers" do
    let(:result) { endpoint.auth_headers }

    it { expect(result).to eq("Authorization" => "Basic #{Base64.strict_encode64("s3cret:x")}") }
  end

  describe "#client" do
    let(:result) { endpoint.client }

    # BambooHR answers in XML unless asked otherwise.
    it { expect(result.headers["Accept"]).to eq("application/json") }
  end

  describe "#access!" do
    let(:result) { endpoint.access! }
    let(:stubs) { Faraday::Adapter::Test::Stubs.new }
    let(:status) { 200 }

    before do
      allow(endpoint).to receive(:client).and_return(
        Faraday.new(url: base_url) do |f|
          f.response :raise_error
          f.adapter(:test, stubs)
        end
      )
      stubs.get("/api/v1/files/view") { [status, {}, { "categories" => [] }.to_json] }
    end

    context "when the key's user can see company files" do
      it { expect { result }.not_to raise_error }
    end

    context "when the key's user can't see company files" do
      let(:status) { 403 }

      it { expect { result }.to raise_error(described_class::Error, /access to company files/) }
    end

    context "when BambooHR rejects the key" do
      let(:status) { 401 }

      it { expect { result }.to raise_error(described_class::Error, /didn't accept this API key/) }
    end
  end

  describe "validations" do
    context "with a company address and a key" do
      it { expect(endpoint).to be_valid }
    end

    context "with an address that isn't BambooHR" do
      let(:base_url) { "https://acme.example.com" }

      it { expect(endpoint).not_to be_valid }
    end

    context "with a path on the address" do
      let(:base_url) { "https://acme.bamboohr.com/api/v1" }

      it { expect(endpoint).not_to be_valid }
    end
  end
end
