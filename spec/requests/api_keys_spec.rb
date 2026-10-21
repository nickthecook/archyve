require "rails_helper"

RSpec.describe "API keys", type: :request do
  describe "POST /account/api_keys" do
    subject(:request) { post account_api_keys_path, params: { name: } }

    context "with a name" do
      let(:name) { "Backup script" }

      it "creates a key for the signed-in user" do
        expect { request }.to change { current_user.api_keys.count }.by(1)
      end

      it "shows the token on the next page" do
        request
        follow_redirect!
        expect(response.body).to include(current_user.api_keys.sole.token_prefix)
          .and include("won’t be shown again")
      end

      it "shows it only once" do
        request
        follow_redirect!
        get account_path
        expect(response.body).not_to include("won’t be shown again")
      end
    end

    context "without a name" do
      let(:name) { "" }

      it "creates nothing" do
        expect { request }.not_to change(ApiKey, :count)
      end
    end
  end

  describe "DELETE /account/api_keys/:id" do
    subject(:request) { delete account_api_key_path(api_key) }

    context "with one of your own keys" do
      let!(:api_key) { create(:api_key, user: current_user) }

      it "deletes it" do
        expect { request }.to change(ApiKey, :count).by(-1)
      end
    end

    context "with somebody else's key" do
      let!(:api_key) { create(:api_key) }

      it "leaves it alone" do
        expect { request }.not_to change(ApiKey, :count)
      end

      it "is not found" do
        request
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
