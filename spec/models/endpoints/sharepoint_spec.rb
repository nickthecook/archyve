require "rails_helper"

RSpec.describe Endpoints::Sharepoint do
  subject(:endpoint) { build(:sharepoint_endpoint, base_url: base_url, tenant_id: tenant_id) }

  let(:base_url) { "https://example.sharepoint.com/sites/Team" }
  let(:tenant_id) { nil }

  describe "validations" do
    context "with a site address, a client id and a secret" do
      it { expect(endpoint).to be_valid }
    end

    context "with a Teams site" do
      let(:base_url) { "https://example.sharepoint.com/teams/Finance" }

      it { expect(endpoint).to be_valid }
    end

    context "with the tenant's root site" do
      let(:base_url) { "https://example.sharepoint.com" }

      it { expect(endpoint).to be_valid }
    end

    # Copying the address bar from a page in the site is the easy mistake, and
    # Graph answers it with a bare "site could not be found".
    context "with a page inside the site" do
      let(:base_url) { "https://example.sharepoint.com/sites/Team/SitePages/Home.aspx" }

      it { expect(endpoint).not_to be_valid }
    end

    context "with a host that isn't SharePoint Online" do
      let(:base_url) { "https://sharepoint.example.com/sites/Team" }

      it { expect(endpoint).not_to be_valid }
    end

    context "when the client id is missing" do
      before { endpoint.client_id = nil }

      it { expect(endpoint).not_to be_valid }
    end

    context "when the secret is missing" do
      subject(:endpoint) { build(:sharepoint_endpoint, client_secret: nil) }

      it { expect(endpoint).not_to be_valid }
    end
  end

  describe "#tenant" do
    let(:result) { endpoint.tenant }

    context "without a directory id" do
      it { expect(result).to eq("example.onmicrosoft.com") }
    end

    context "with a directory id" do
      let(:tenant_id) { "11111111-2222-3333-4444-555555555555" }

      it { expect(result).to eq(tenant_id) }
    end
  end

  describe "#site_path" do
    let(:result) { endpoint.site_path }

    context "with a site under /sites" do
      it { expect(result).to eq("sites/example.sharepoint.com:/sites/Team") }
    end

    context "with the root site" do
      let(:base_url) { "https://example.sharepoint.com" }

      it { expect(result).to eq("sites/example.sharepoint.com") }
    end

    context "with something beneath a site under /sites" do
      let(:result) { endpoint.site_path("drives") }

      it { expect(result).to eq("sites/example.sharepoint.com:/sites/Team:/drives") }
    end

    context "with something beneath the root site" do
      let(:base_url) { "https://example.sharepoint.com" }
      let(:result) { endpoint.site_path("drives") }

      it { expect(result).to eq("sites/example.sharepoint.com/drives") }
    end
  end

  describe "#access" do
    subject(:endpoint) { create(:sharepoint_endpoint) }

    let(:result) { endpoint.access }
    let(:stubs) { Faraday::Adapter::Test::Stubs.new }
    let(:token_path) { "/example.onmicrosoft.com/oauth2/v2.0/token" }
    let(:site_path) { "/v1.0/sites/example.sharepoint.com:/sites/Team" }
    let(:token_response) { [200, {}, { access_token: "graph-token", expires_in: 3599 }.to_json] }
    let(:site_response) { [200, {}, { id: "example.sharepoint.com,a,b" }.to_json] }

    before do
      allow(Http).to receive(:connection) do |url, **|
        Faraday.new(url: url) do |f|
          f.request :url_encoded
          f.adapter(:test, stubs)
        end
      end

      stubs.post(token_path, ->(body) { body.include?("client_secret=client-secret") }) { token_response }
      stubs.get(site_path, { "Authorization" => "Bearer graph-token" }) { site_response }
    end

    context "when another instance of the same endpoint already fetched a token" do
      before { Endpoint.find(endpoint.id).access }

      it "re-uses it" do
        result
        expect(Http).to have_received(:connection).with(described_class::LOGIN_URL, anything).once
      end
    end

    context "when the endpoint was saved after the token was fetched" do
      before do
        Endpoint.find(endpoint.id).access
        endpoint.update!(client_secret: "client-secret", updated_at: 1.minute.from_now)
      end

      it "fetches a new one" do
        result
        expect(Http).to have_received(:connection).with(described_class::LOGIN_URL, anything).twice
      end
    end

    context "when Entra issues a token and Graph finds the site" do
      it { expect(result).to be(true) }
    end

    context "when Entra rejects the secret" do
      let(:token_response) do
        [401, {}, { error: "invalid_client", error_description: "AADSTS7000215: Invalid client secret provided.\r\nTrace ID: x" }.to_json]
      end

      it "records Entra's reason" do
        result
        expect(endpoint.access_error).to eq("Endpoints::Sharepoint::Error: AADSTS7000215: Invalid client secret provided.")
      end
    end

    context "when Graph can't find the site" do
      let(:site_response) { [404, {}, { error: { code: "itemNotFound", message: "Requested site could not be found" } }.to_json] }

      it "names the address it looked for" do
        result
        expect(endpoint.access_error).to include("no site at https://example.sharepoint.com/sites/Team")
      end
    end

    context "when Graph refuses the app" do
      let(:site_response) { [403, {}, { error: { code: "accessDenied", message: "Access denied" } }.to_json] }

      it "records Graph's reason" do
        result
        expect(endpoint.access_error).to eq("Endpoints::Sharepoint::Error: accessDenied: Access denied")
      end
    end
  end
end
