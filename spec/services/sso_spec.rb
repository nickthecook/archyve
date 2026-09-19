require "rails_helper"

RSpec.describe Sso, type: :model do
  describe ".configured?" do
    context "with every setting present" do
      it "is configured" do
        configure_sso

        expect(described_class).to be_configured
      end
    end

    # The group is part of "configured" on purpose: there is no half-set state
    # where SSO is on but ungated, so forgetting one variable can't quietly let
    # the whole realm in.
    described_class::SETTINGS.each do |missing|
      context "with #{missing} missing" do
        it "is not configured" do
          configure_sso
          ENV.delete(missing)

          expect(described_class).not_to be_configured
        end
      end
    end

    context "when a setting is blank rather than absent" do
      it "is not configured" do
        configure_sso
        ENV["ARCHYVE_SSO_GROUP"] = ""

        expect(described_class).not_to be_configured
      end
    end
  end

  describe ".discover" do
    context "when SSO is not configured" do
      it "refuses rather than calling out" do
        expect { described_class.discover }.to raise_error(Sso::NotConfigured)
      end
    end

    context "when it is" do
      before do
        configure_sso
        stub_sso_http
      end

      it "reads the endpoints from the provider" do
        expect(described_class.token_endpoint).to eq("#{SsoHelpers::ISSUER}/protocol/openid-connect/token")
        expect(described_class.end_session_endpoint).to eq("#{SsoHelpers::ISSUER}/protocol/openid-connect/logout")
      end
    end
  end

  describe ".issuer" do
    # Discovery and the iss claim are both compared against this, and a stray
    # trailing slash would make both fail confusingly.
    it "drops a trailing slash" do
      configure_sso
      ENV["ARCHYVE_SSO_ISSUER"] = "#{SsoHelpers::ISSUER}/"

      expect(described_class.issuer).to eq(SsoHelpers::ISSUER)
    end
  end
end
