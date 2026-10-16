require "rails_helper"

RSpec.describe "Settings::DefaultModels", :unauthenticated, type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:model) { create(:inference_model, :tools, name: "gpt-oss:20b") }

  before { sign_in(admin) }

  describe "GET /settings/inference_servers" do
    subject(:request) { get settings_inference_servers_path }

    it "offers the choice where the servers are" do
      request
      expect(response.body).to include("Default chat model").and include("gpt-oss:20b")
    end

    it "offers a way back to no choice at all" do
      request
      expect(response.body).to include("First available")
    end

    context "with no chat model configured" do
      before { InferenceModel.delete_all }

      it "says nothing rather than offering an empty picker" do
        request
        expect(response.body).not_to include("Default chat model")
      end
    end
  end

  describe "PATCH /settings/default_model" do
    context "with a usable chat model" do
      it "sets it" do
        patch settings_default_model_path, params: { inference_model_id: model.id }
        expect(Setting.chat_default_model_id).to eq(model.id)
      end

      it "goes back to the page it was chosen on" do
        patch settings_default_model_path, params: { inference_model_id: model.id }
        expect(response).to redirect_to(settings_inference_servers_path)
      end
    end

    context "with the blank option" do
      before { Setting["chat.default_model_id"] = model.id }

      it "clears it rather than storing a zero" do
        patch settings_default_model_path, params: { inference_model_id: "" }
        expect(Setting.chat_default_model_id).to be_nil
      end
    end

    # The page only offers tool-capable chat models, but hiding an option is
    # not enforcement — see CLAUDE.md.
    context "with a model that can't call tools" do
      let!(:toolless) { create(:inference_model, name: "no-tools") }

      it "refuses it" do
        patch settings_default_model_path, params: { inference_model_id: toolless.id }
        expect(Setting.chat_default_model_id).to be_nil
      end

      it "says why" do
        patch settings_default_model_path, params: { inference_model_id: toolless.id }
        expect(flash[:alert]).to include("can't be the default")
      end
    end

    context "with an id that names nothing" do
      it "refuses it" do
        patch settings_default_model_path, params: { inference_model_id: "999999" }
        expect(Setting.chat_default_model_id).to be_nil
      end
    end

    context "as an operator" do
      let(:operator) { create(:user, :operator) }

      before { sign_in(operator) }

      it "is refused, like everything else under Settings" do
        patch settings_default_model_path, params: { inference_model_id: model.id }
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
