require "rails_helper"

RSpec.describe "Settings::Brandings", :unauthenticated, type: :request do
  let(:admin) { create(:user, :admin) }
  let(:logo) { fixture_file_upload("logo.png", "image/png") }

  before { sign_in(admin) }

  describe "GET /settings/branding" do
    subject(:request) { get settings_branding_path }

    context "when nothing has been set" do
      it "shows Archyve's own name" do
        request
        expect(response.body).to include('value="ARCHYVE"')
      end
    end

    context "when a logo has been uploaded" do
      before { Setting["brand.logo"] = logo }

      it "offers to remove it" do
        request
        expect(response.body).to include("Remove logo")
      end
    end
  end

  describe "PATCH /settings/branding" do
    subject(:request) { patch settings_branding_path, params: }

    let(:params) { { name: "Acme", ask_placeholder: "Ask Acme", chat_placeholder: "" } }

    context "with text settings" do
      it "stores the name" do
        request
        expect(Setting.brand_name).to eq("Acme")
      end

      it "stores a placeholder" do
        request
        expect(Setting.brand_ask_placeholder).to eq("Ask Acme")
      end

      it "redirects to Settings" do
        request
        expect(response).to redirect_to(settings_path)
      end
    end

    context "with a blank placeholder that had been changed" do
      before { Setting["brand.chat_placeholder"] = "Go on, ask" }

      it "goes back to the default" do
        request
        expect(Setting.brand_chat_placeholder).to eq("What do you want to know?")
      end
    end

    context "with a blank disclaimer that had been set" do
      before { Setting["brand.disclaimer"] = "Check with your manager." }

      it "removes it" do
        request
        expect(Setting.brand_disclaimer).to eq("")
      end
    end

    context "when the corridor is turned off" do
      let(:params) { { name: "ARCHYVE", corridor: "0" } }

      it "stores it" do
        request
        expect(Setting.brand_corridor?).to be(false)
      end
    end

    context "when everything is left at its default" do
      let(:params) { { name: "ARCHYVE", ask_placeholder: "Consult the archive", corridor: "1" } }

      it "stores nothing, so Settings still reads as default" do
        request
        expect(Setting.where("key LIKE 'brand.%'")).to be_empty
      end
    end

    context "with a landing image that isn't an image" do
      let(:params) { { name: "Acme", landing_image: fixture_file_upload("sample.md", "text/markdown") } }

      it "names the landing image in the error" do
        request
        expect(response.body).to include("The landing image has an invalid content type")
      end
    end

    context "with a blank name" do
      let(:params) { { name: "" } }

      it "stores it blank rather than restoring the default" do
        request
        expect(Setting.brand_name).to eq("")
      end
    end

    context "with a logo" do
      let(:params) { { name: "Acme", logo: } }

      it "attaches it" do
        request
        expect(Setting.brand_logo).to be_attached
      end

      it "shows it in the header" do
        request
        follow_redirect!
        expect(response.body).to include("/rails/active_storage/blobs/")
      end

      it "makes it the favicon" do
        request
        follow_redirect!
        expect(response.body).to match(%r{<link rel="icon" href="/rails/active_storage/representations/[^"]+" type="image/png">})
      end
    end

    context "with a file that isn't an image" do
      let(:params) { { name: "Acme", logo: fixture_file_upload("sample.md", "text/markdown") } }

      it "refuses it" do
        request
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "saves nothing else either" do
        request
        expect(Setting.brand_name).to eq("ARCHYVE")
      end

      it "keeps what was typed" do
        request
        expect(response.body).to include('value="Acme"')
      end
    end

    context "with an SVG" do
      let(:svg) do
        Rack::Test::UploadedFile.new(
          StringIO.new('<svg xmlns="http://www.w3.org/2000/svg"/>'), "image/svg+xml", original_filename: "logo.svg"
        )
      end
      let(:params) { { name: "Acme", logo: svg } }

      it "refuses it, since it wouldn't render" do
        request
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when removing the logo" do
      let(:params) { { name: "Acme", remove_logo: "1" } }

      before { Setting["brand.logo"] = logo }

      it "goes back to the triangle mark" do
        request
        expect(Setting.brand_logo).to be_nil
      end
    end
  end

  describe "the uploaded logo" do
    before do
      Setting["brand.logo"] = logo
      delete session_path
    end

    it "is served to people who haven't signed in, for the sign-in page" do
      get Rails.application.routes.url_helpers.rails_blob_path(Setting.brand_logo, only_path: true)
      expect(response).to redirect_to(%r{/rails/active_storage/disk/})
    end
  end

  context "when signed in as a curator" do
    let(:curator) { create(:user, :curator) }

    before { sign_in(curator) }

    it "refuses" do
      get settings_branding_path
      expect(response).to redirect_to(root_path)
    end
  end
end
