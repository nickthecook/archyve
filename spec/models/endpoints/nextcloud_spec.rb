require "rails_helper"

RSpec.describe Endpoints::Nextcloud do
  subject(:endpoint) { build(:nextcloud_endpoint, username: "archyve", app_password: "s3cret") }

  describe "#auth_headers" do
    # Nextcloud takes an app password exactly where it takes a password, so this
    # is plain Basic. Getting the shape wrong reads as a rejected password
    # rather than as a malformed request.
    it "sends the username and app password as HTTP Basic" do
      expect(endpoint.auth_headers).to eq(
        "Authorization" => "Basic #{Base64.strict_encode64("archyve:s3cret")}"
      )
    end
  end

  describe "#dav_root" do
    # Relative, so Faraday appends it to the base URL rather than replacing that
    # URL's own path — see #dav_href_prefix.
    context "with an ordinary username" do
      it { expect(endpoint.dav_root).to eq("remote.php/dav/files/archyve") }
    end

    # Nextcloud user ids may hold spaces and @ signs, and the root is a URL path
    # rather than a label.
    context "with a username needing escaping" do
      subject(:endpoint) { build(:nextcloud_endpoint, username: "ada lovelace@example.com") }

      it { expect(endpoint.dav_root).to eq("remote.php/dav/files/ada%20lovelace%40example.com") }
    end
  end

  describe "#dav_href_prefix" do
    context "with the server at an origin" do
      subject(:endpoint) { build(:nextcloud_endpoint, base_url: "https://cloud.test", username: "archyve") }

      it { expect(endpoint.dav_href_prefix).to eq("/remote.php/dav/files/archyve") }
    end

    # What the server writes in a `d:href` carries whatever path the base URL
    # has, so matching against the bare DAV root would reject every entry.
    context "with the server under a subpath" do
      subject(:endpoint) do
        build(:nextcloud_endpoint, base_url: "https://example.com/nextcloud", username: "archyve")
      end

      it { expect(endpoint.dav_href_prefix).to eq("/nextcloud/remote.php/dav/files/archyve") }
    end
  end

  describe "validations" do
    context "with an address, a username and an app password" do
      it { expect(endpoint).to be_valid }
    end

    context "when the username is missing" do
      before { endpoint.username = nil }

      it { expect(endpoint).not_to be_valid }
    end

    # Half a credential pair authenticates nothing, so the password is required
    # on the way in — notwithstanding that a blank *assignment* later leaves an
    # existing one alone.
    context "when the app password is missing" do
      subject(:endpoint) { build(:nextcloud_endpoint, app_password: nil) }

      it { expect(endpoint).not_to be_valid }
    end

    context "when the base url is missing" do
      before { endpoint.base_url = nil }

      it { expect(endpoint).not_to be_valid }
    end
  end

  describe "#access" do
    subject(:endpoint) { create(:nextcloud_endpoint, base_url: "https://cloud.test", username: "archyve") }

    let(:stubs) { Faraday::Adapter::Test::Stubs.new }
    let(:root) { "/remote.php/dav/files/archyve" }

    # raise_error is carried over from Http's real stack deliberately: it is what
    # turns the 401 a wrong password produces into something #access can record,
    # so a test connection without it would prove nothing about the failure path.
    before do
      allow(Http).to receive(:connection).and_return(
        Faraday.new(url: endpoint.base_url) do |f|
          f.response :raise_error
          f.adapter(:test, stubs)
        end
      )
    end

    context "when the server answers for that user's root" do
      before do
        stubs.send(:new_stub, :propfind, root, { "Authorization" => "Basic #{Base64.strict_encode64("archyve:apppassword")}" }) do
          [207, { "Content-Type" => "application/xml" },
           %(<?xml version="1.0"?><d:multistatus xmlns:d="DAV:"><d:response><d:href>#{root}/</d:href></d:response></d:multistatus>)]
        end
      end

      it "succeeds" do
        expect(endpoint.access).to be(true)
      end

      # A request that doesn't carry Basic auth matches no stub, and Faraday's
      # test adapter fails the example rather than quietly passing.
      it "makes the authenticated call against the user's own root" do
        endpoint.access!

        stubs.verify_stubbed_calls
      end
    end

    context "when the server rejects the app password" do
      before { stubs.send(:new_stub, :propfind, root) { [401, {}, ""] } }

      it "is recorded as a failure rather than raising" do
        expect(endpoint.access).to be(false)
        expect(endpoint).not_to be_accessible
      end
    end
  end
end
