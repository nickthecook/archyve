require "rails_helper"

RSpec.describe "Settings::Purposes", :unauthenticated, type: :request do
  let(:user) { create(:user, :admin) }

  before { sign_in(user) }

  describe "PATCH /settings/purpose" do
    subject(:request) { patch settings_purpose_path, params: { purpose: "  Answer company policy questions. " } }

    it "stores it, trimmed" do
      request
      expect(Setting.chat_instance_purpose).to eq("Answer company policy questions.")
    end

    it "returns to Agents" do
      request
      expect(response).to redirect_to(settings_agents_path)
    end

    context "when signed in as a curator" do
      let(:user) { create(:user, :curator) }

      it "refuses" do
        request
        expect(Setting.chat_instance_purpose).to be_blank
      end
    end
  end
end
