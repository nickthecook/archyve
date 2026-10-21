require "rails_helper"

RSpec.describe "Settings::Preferences", :unauthenticated, type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    sign_in(admin)
    # Pinned so the suite doesn't read whoever's shell set it for their own
    # debugging — see ApiCall.recording?.
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("ARCHYVE_RECORD_API_CALLS", nil).and_return(nil)
    %w[SEARCH READ LISTING].each do |budget|
      allow(ENV).to receive(:fetch).with("ARCHYVE_CHAT_MAX_#{budget}_ROUNDS", nil).and_return(nil)
    end
  end

  describe "GET /settings" do
    subject(:request) { get settings_path }

    it "offers the toggles" do
      request
      expect(response.body).to include("Record outgoing API calls", "Record incoming API calls")
    end

    it "offers every round budget" do
      request
      expect(response.body)
        .to include("Searches per turn").and include("Documents read per turn").and include("Listings per turn")
    end

    it "shows what it is currently set to" do
      Setting["chat.max_read_rounds"] = 7
      request
      expect(response.body).to include('name="value" value="7"')
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

    context "when changing a number" do
      let(:params) { { key: "chat.max_read_rounds", value: "6" } }

      it "takes effect" do
        request
        expect(Setting.chat_max_read_rounds).to eq(6)
      end

      context "when Turbo asks for a stream" do
        subject(:request) do
          patch settings_preferences_path, params: params, as: :turbo_stream
        end

        it "swaps just the one row" do
          request
          expect(response.body).to include(%(target="#{Views::Settings::Number.dom_id('chat.max_read_rounds')}"))
        end

        it "sends back the saved value" do
          request
          expect(response.body).to include('name="value" value="6"')
        end
      end

      context "with a value that isn't a number" do
        let(:params) { { key: "chat.max_read_rounds", value: "lots" } }

        it "refuses rather than storing a zero" do
          request
          expect(Setting.chat_max_read_rounds).to eq(4)
        end

        it "says so" do
          request
          expect(flash[:alert]).to eq("That needs to be a number, 1 or more.")
        end
      end

      # Zero is the dangerous one: it reads as a setting rather than a mistake,
      # and leaves the model a tool it can never call.
      context "with a value of zero" do
        let(:params) { { key: "chat.max_read_rounds", value: "0" } }

        it "refuses" do
          request
          expect(Setting.chat_max_read_rounds).to eq(4)
        end
      end
    end

    context "with a setting the index renders no control for" do
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
