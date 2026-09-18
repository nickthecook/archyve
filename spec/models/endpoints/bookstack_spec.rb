require "rails_helper"

RSpec.describe Endpoints::Bookstack do
  subject(:endpoint) { build(:bookstack_endpoint, token_id: "abc", token_secret: "xyz") }

  describe "#auth_headers" do
    # BookStack wants the pair in one header, colon-separated. Getting this
    # shape wrong reads as a rejected token rather than as a malformed request.
    it "sends the id and secret as a BookStack token" do
      expect(endpoint.auth_headers).to eq("Authorization" => "Token abc:xyz")
    end
  end

  describe "validations" do
    context "when the token id is missing" do
      before { endpoint.token_id = nil }

      it "is invalid" do
        expect(endpoint).not_to be_valid
      end
    end

    # Half a credential pair authenticates nothing, so the secret is required on
    # the way in — notwithstanding that a blank *assignment* later leaves an
    # existing secret alone.
    context "when the token secret is missing" do
      subject(:endpoint) { build(:bookstack_endpoint, token_secret: nil) }

      it "is invalid" do
        expect(endpoint).not_to be_valid
      end
    end

    context "when the base url is missing" do
      before { endpoint.base_url = nil }

      it "is invalid" do
        expect(endpoint).not_to be_valid
      end
    end
  end

  describe "#access!" do
    subject(:endpoint) { create(:bookstack_endpoint, base_url: "https://wiki.test") }

    let(:stubs) { Faraday::Adapter::Test::Stubs.new }

    # raise_error is carried over from Http's real stack deliberately: it is
    # what turns the 401 a wrong secret produces into something #access can
    # record, so a test connection without it would prove nothing about the
    # failure path below.
    before do
      allow(Http).to receive(:connection).and_return(
        Faraday.new do |f|
          f.response :raise_error
          f.adapter(:test, stubs)
        end
      )
    end

    context "when the wiki answers" do
      # The header match is the assertion. A request that doesn't carry the
      # BookStack token in the right shape matches no stub, and Faraday's test
      # adapter fails the example rather than quietly passing.
      before do
        stubs.get("/api/books?count=1", { "Authorization" => "Token tokenid:tokensecret" }) { [200, {}, "{}"] }
      end

      it "succeeds" do
        expect(endpoint.access).to be(true)
      end

      it "makes the authenticated call" do
        endpoint.access!

        stubs.verify_stubbed_calls
      end
    end

    context "when the wiki rejects the token" do
      before { stubs.get("/api/books?count=1") { [401, {}, ""] } }

      it "is recorded as a failure rather than raising" do
        expect(endpoint.access).to be(false)
        expect(endpoint).not_to be_accessible
      end
    end
  end
end
