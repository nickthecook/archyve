require "rails_helper"

RSpec.describe "Settings::Admin", :unauthenticated, type: :request do
  before { sign_in(create(:user, :admin)) }

  describe "GET /settings/admin" do
    subject(:request) { get settings_admin_path }

    it "lists the models that have a page" do
      request
      expect(response.body).to include("API calls", settings_api_calls_path)
    end

    context "with nothing recorded" do
      before { Setting["debug.record_api_calls"] = false }

      it "says whether anything is being kept rather than counting zero" do
        request
        expect(response.body).to include("not recording")
      end
    end

    context "with calls recorded" do
      before { create_list(:api_call, 2) }

      it "counts them" do
        request
        expect(response.body).to include("2 calls")
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

  describe "GET /settings" do
    it "offers the way in" do
      get settings_path
      expect(response.body).to include(settings_admin_path)
    end

    # It leaves Settings for a different kind of page, so it is a doorway above
    # the rule rather than another row of the menu — see docs/design.md.
    it "gives it the accent rail, and nothing else on the page" do
      get settings_path
      expect(response.body.scan("border-l-accent").size).to eq(1)
    end
  end
end
