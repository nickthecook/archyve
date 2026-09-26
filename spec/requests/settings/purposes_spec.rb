require "rails_helper"

RSpec.describe "Settings::Purposes", :unauthenticated, type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in(admin) }

  describe "GET /settings/purpose" do
    subject(:request) { get settings_purpose_path }

    context "when nothing has been set" do
      it "shows an empty form" do
        request
        expect(response.body).to include("Instance purpose")
      end
    end

    context "when a purpose has been set" do
      before { Setting["chat.instance_purpose"] = "Answer questions for my family." }

      it "shows it" do
        request
        expect(response.body).to include("Answer questions for my family.")
      end
    end
  end

  describe "PATCH /settings/purpose" do
    subject(:request) { patch settings_purpose_path, params: { purpose: "Answer company policy questions." } }

    it "stores it" do
      request
      expect(Setting.chat_instance_purpose).to eq("Answer company policy questions.")
    end

    it "redirects to Settings" do
      request
      expect(response).to redirect_to(settings_path)
    end
  end

  context "when signed in as an operator" do
    let(:operator) { create(:user, :operator) }

    before { sign_in(operator) }

    it "refuses" do
      get settings_purpose_path
      expect(response).to redirect_to(root_path)
    end
  end
end
