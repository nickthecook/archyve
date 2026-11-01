require "rails_helper"

RSpec.describe "Help", type: :request do
  subject(:request) { get "/help/#{path}" }

  before { allow(HelpPage).to receive(:root).and_return(Rails.root.join("spec/fixtures/files/help")) }

  describe "GET /help/*path" do
    let(:path) { "guide/setup" }

    it "renders the page" do
      request
      expect(response.body).to include("First steps")
    end

    it "marks the page in the contents" do
      request
      expect(response.body).to include('href="/help/guide/setup" aria-current="page"')
    end

    context "with an image's path" do
      let(:path) { "guide/images/diagram.png" }

      it "serves the image" do
        request
        expect(response.media_type).to eq("image/png")
      end
    end

    context "with no such page" do
      let(:path) { "guide/missing" }

      it "is not found" do
        request
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with a file that isn't a page or an image" do
      let(:path) { "_sidebar.md" }

      it "is not found" do
        request
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in as a visitor" do
      before { sign_in(create(:user)) }

      it "renders the page" do
        request
        expect(response).to have_http_status(:ok)
      end
    end

    context "when signed out", :unauthenticated do
      it "redirects to sign-in" do
        request
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
