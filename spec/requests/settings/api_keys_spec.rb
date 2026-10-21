require "rails_helper"

RSpec.describe "Settings::ApiKeys", :unauthenticated, type: :request do
  before { sign_in(create(:user, :admin)) }

  describe "GET /settings/api_keys" do
    subject(:request) { get settings_api_keys_path }

    context "with none to show" do
      it "says so rather than showing an empty table" do
        request
        expect(response.body).to include("No API keys yet")
      end
    end

    context "with a key whose owner signed in recently" do
      let!(:api_key) { create(:api_key, user: create(:user, last_signed_in_at: 1.day.ago)) }

      it "lists it with its owner" do
        request
        expect(response.body).to include(api_key.user.email_address)
      end

      it "doesn't flag it" do
        request
        expect(response.body).not_to include("not signed in lately")
      end
    end

    context "with a key whose owner hasn't signed in for over 30 days" do
      before { create(:api_key, user: create(:user, last_signed_in_at: 31.days.ago)) }

      it "flags it" do
        request
        expect(response.body).to include("not signed in lately")
      end
    end

    context "when an operator asks" do
      before { sign_in(create(:user, :operator)) }

      it "is refused" do
        request
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /settings/api_keys/:id" do
    let(:api_key) { create(:api_key) }

    it "renders the record" do
      get settings_api_key_path(api_key)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "DELETE /settings/api_keys/:id" do
    subject(:request) { delete settings_api_key_path(api_key) }

    let!(:api_key) { create(:api_key) }

    it "deletes anyone's key" do
      expect { request }.to change(ApiKey, :count).by(-1)
    end
  end
end
