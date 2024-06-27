require 'rails_helper'

RSpec.describe Client do
  subject { described_class.new(name:, user:, api_key:, client_id:) }

  let(:name) { 'Test Client' }
  let(:user) { create(:user) }
  let(:client_id) { described_class.new_client_id }
  let(:api_key) { described_class.new_api_key }

  describe "validation" do
    before do
      subject.validate
    end

    it "is valid" do
      expect(subject).to be_valid
    end

    context "when api_key is nil" do
      let(:api_key) { nil }

      it "is invalid" do
        expect(subject).not_to be_valid
      end

      it "returns a descriptive error" do
        expect(subject.errors[:api_key]).to include("is required")
      end
    end

    context "when api_key is invalid" do
      let(:api_key) { 'invalid' }

      it "is invalid" do
        expect(subject).not_to be_valid
      end

      it "returns a descriptive error" do
        expect(subject.errors[:api_key]).to include("must be exactly 64 base64 characters")
      end
    end

    context "when api_key is not base64" do
      let(:api_key) { ' ' * 64 }

      it "is invalid" do
        expect(subject).not_to be_valid
      end

      it "returns a descriptive error" do
        expect(subject.errors[:api_key]).to include("must be a valid base64 string")
      end
    end
  end

  describe ".new_client_id" do
    it "returns a new client id" do
      expect(described_class.new_client_id).to be_a_uuid
    end
  end

  describe ".new_api_key" do
    it "returns a new api key" do
      expect(described_class.new_api_key).to match(/^[a-zA-Z0-9=\/+]{64}$/)
    end
  end

  describe "#collections" do
    let(:collections) { create_list(:collection, 3) }

    it "returns all collections" do
      expect(described_class.new.collections).to eq collections
    end
  end
end
