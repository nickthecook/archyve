require "rails_helper"

RSpec.describe "Settings::Preferences", :unauthenticated, type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    sign_in(admin)
    # Pinned so the suite doesn't read whoever's shell set it for their own
    # debugging — see ApiCall.recording?.
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("ARCHYVE_RECORD_API_CALLS", nil).and_return(nil)
  end

  describe "GET /settings" do
    subject(:request) { get settings_path }

    it "offers the toggle" do
      request
      expect(response.body).to include("Record API calls")
    end

    context "when the setting is off" do
      it "shows the switch off" do
        request
        expect(response.body).to include('aria-checked="false"')
      end

      it "offers to turn it on" do
        request
        expect(response.body).to include('name="value" value="true"')
      end
    end

    context "when the setting is on" do
      before { Setting["debug.record_api_calls"] = true }

      it "shows the switch on" do
        request
        expect(response.body).to include('aria-checked="true"')
      end

      it "offers to turn it off" do
        request
        expect(response.body).to include('name="value" value="false"')
      end
    end
  end

  describe "PATCH /settings/preferences" do
    subject(:request) { patch settings_preferences_path, params: params }

    let(:params) { { key: "debug.record_api_calls", value: "true" } }

    context "when turning a setting on" do
      it "takes effect without a save step" do
        request
        expect(Setting.record_api_calls?).to be(true)
      end

      it "redirects for a plain form post" do
        request
        expect(response).to redirect_to(settings_path)
      end
    end

    context "when turning a setting off" do
      let(:params) { { key: "debug.record_api_calls", value: "false" } }

      before { Setting["debug.record_api_calls"] = true }

      it "takes effect" do
        request
        expect(Setting.record_api_calls?).to be(false)
      end
    end

    context "when Turbo asks for a stream" do
      subject(:request) do
        patch settings_preferences_path, params: params, as: :turbo_stream
      end

      it "swaps just the one row" do
        request
        expect(response.body).to include(%(target="#{Views::Settings::Toggle.dom_id('debug.record_api_calls')}"))
      end

      it "sends back the flipped switch" do
        request
        expect(response.body).to include('aria-checked="true"')
      end
    end

    context "with a setting that is not a toggle" do
      let(:params) { { key: "chat.result_limit", value: "true" } }

      it "refuses rather than writing a boolean into it" do
        request
        expect(Setting.chat_result_limit).to eq(6)
      end

      it "says so" do
        request
        expect(flash[:alert]).to eq("No such setting.")
      end
    end

    context "with a key that does not exist" do
      let(:params) { { key: "nope.not.a.setting", value: "true" } }

      it "refuses" do
        request
        expect(response).to redirect_to(settings_path)
      end
    end
  end

  context "when signed in as an operator" do
    let(:operator) { create(:user, :operator) }

    before { sign_in(operator) }

    it "refuses" do
      patch settings_preferences_path, params: { key: "debug.record_api_calls", value: "true" }
      expect(response).to redirect_to(root_path)
    end
  end
end
