require "rails_helper"

RSpec.describe "Theme", type: :request do
  subject(:page) do
    cookies[:theme] = theme if theme
    get new_session_path
    Nokogiri::HTML(response.body)
  end

  let(:html) { page.at("html") }

  describe "the sign-in page", :unauthenticated do
    context "with no choice made" do
      let(:theme) { nil }

      it "leaves the theme to the device" do
        expect(html["data-theme"]).to be_nil
      end

      it "offers the toggle at system" do
        expect(page.at("[data-controller=theme]")["data-theme-choice-value"]).to eq("system")
      end
    end

    context "with light chosen" do
      let(:theme) { "light" }

      it "renders light before first paint" do
        expect(html["data-theme"]).to eq("light")
      end
    end

    context "with dark chosen" do
      let(:theme) { "dark" }

      it "renders dark before first paint" do
        expect(html["data-theme"]).to eq("dark")
      end
    end

    context "with system chosen" do
      let(:theme) { "system" }

      it "leaves the theme to the device" do
        expect(html["data-theme"]).to be_nil
      end
    end

    context "with a value it doesn't know" do
      let(:theme) { "sepia" }

      it "falls back to the device" do
        expect(html["data-theme"]).to be_nil
      end
    end
  end
end
