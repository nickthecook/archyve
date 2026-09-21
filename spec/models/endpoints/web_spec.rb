require "rails_helper"

RSpec.describe Endpoints::Web do
  subject(:endpoint) { build(:web_endpoint, **attributes) }

  let(:attributes) { {} }

  describe "validations" do
    context "with just an origin" do
      it { expect(endpoint).to be_valid }
    end

    # The path belongs to the source, and Faraday resolves a relative request
    # against a base *path* by replacing its last segment — so a path here
    # would quietly re-root every crawled URL.
    context "with a path on the address" do
      let(:attributes) { { base_url: "https://docs.test/docs" } }

      it "rejects it" do
        endpoint.valid?
        expect(endpoint.errors[:base_url]).to include(a_string_including("put the path in the Path field"))
      end
    end

    context "with a path" do
      let(:attributes) { { path_prefix: "/wiki" } }

      it { expect(endpoint).to be_valid }
    end

    context "with a full address as the path" do
      let(:attributes) { { path_prefix: "https://docs.test/wiki" } }

      it "rejects it" do
        endpoint.valid?
        expect(endpoint.errors[:path_prefix]).to include(a_string_including("must be a path"))
      end
    end

    context "with Basic chosen and no password" do
      let(:attributes) { { auth_scheme: "basic", username: "archyve" } }

      it { expect(endpoint).not_to be_valid }
    end

    context "with Basic fully configured" do
      let(:attributes) { { auth_scheme: "basic", username: "archyve", password: "hunter2" } }

      it { expect(endpoint).to be_valid }
    end

    context "with a fixed header and no value" do
      let(:attributes) { { auth_scheme: "header", header_name: "X-Api-Key" } }

      it { expect(endpoint).not_to be_valid }
    end

    context "with a fixed header and no name" do
      let(:attributes) { { auth_scheme: "header", header_value: "Bearer abc123" } }

      it { expect(endpoint).to be_valid }
    end
  end

  # The accessor reports what is stored and nothing more. Defaulting it here
  # would put "Authorization" into the form as typed content rather than as a
  # placeholder, and save it to config for an endpoint that sends no header.
  describe "#header_name" do
    context "with nothing set" do
      it { expect(endpoint.header_name).to be_nil }
    end

    context "with a name set" do
      let(:attributes) { { header_name: "X-Api-Key" } }

      it { expect(endpoint.header_name).to eq("X-Api-Key") }
    end
  end

  describe "#auth_headers" do
    let(:result) { endpoint.auth_headers }

    context "with no sign-in configured" do
      it { expect(result).to eq({}) }
    end

    context "with Basic" do
      let(:attributes) { { auth_scheme: "basic", username: "archyve", password: "hunter2" } }

      it { expect(result).to eq("Authorization" => "Basic #{Base64.strict_encode64("archyve:hunter2")}") }
    end

    context "with a fixed header" do
      let(:attributes) { { auth_scheme: "header", header_name: "X-Api-Key", header_value: "abc123" } }

      it { expect(result).to eq("X-Api-Key" => "abc123") }
    end

    context "with a fixed header and no name given" do
      let(:attributes) { { auth_scheme: "header", header_value: "Bearer abc123" } }

      it { expect(result).to eq("Authorization" => "Bearer abc123") }
    end
  end

  # Blank means "unchanged", so an edit form can render a secret as an empty
  # field and mean it.
  describe "#password=" do
    let(:endpoint) { create(:web_endpoint, auth_scheme: "basic", username: "archyve", password: "hunter2") }

    context "with a blank value" do
      it "keeps the stored one" do
        endpoint.password = ""
        expect(endpoint.password).to eq("hunter2")
      end
    end

    context "with a new value" do
      it "replaces it" do
        endpoint.password = "correct-horse"
        expect(endpoint.password).to eq("correct-horse")
      end
    end
  end
end
