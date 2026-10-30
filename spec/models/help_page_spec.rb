require "rails_helper"

RSpec.describe HelpPage do
  let(:fixtures) { Rails.root.join("spec/fixtures/files/help") }

  before { allow(described_class).to receive(:root).and_return(fixtures) }

  describe ".find" do
    subject(:result) { described_class.find(path) }

    context "with no path" do
      let(:path) { nil }

      it { expect(result.relative).to eq("index.md") }
    end

    context "with a page's path" do
      let(:path) { "guide/setup" }

      it { expect(result.relative).to eq("guide/setup.md") }
    end

    context "with a directory's path" do
      let(:path) { "guide" }

      it { expect(result.relative).to eq("guide/index.md") }
    end

    context "with no such page" do
      let(:path) { "guide/missing" }

      it { expect(result).to be_nil }
    end

    context "with a path that climbs out of the root" do
      let(:path) { "guide/../../README" }

      it { expect(result).to be_nil }
    end

    context "with the sidebar's path" do
      let(:path) { "_sidebar" }

      it { expect(result).to be_nil }
    end
  end

  describe ".image" do
    subject(:result) { described_class.image(path) }

    context "with an image's path" do
      let(:path) { "guide/images/diagram.png" }

      it { expect(result).to eq(fixtures.join(path)) }
    end

    context "with a markdown file's path" do
      let(:path) { "guide/setup.md" }

      it { expect(result).to be_nil }
    end

    context "with a path that climbs out of the root" do
      let(:path) { "../help/guide/images/diagram.png" }

      it { expect(result).to be_nil }
    end
  end

  describe "#html" do
    subject(:html) { Nokogiri::HTML5.fragment(page.html(current:)) }

    let(:page) { described_class.find("guide/setup") }
    let(:current) { nil }
    let(:hrefs) { html.css("a:not(.anchor)").map { it["href"] } }

    it "points relative links at their help URLs" do
      expect(hrefs).to include("/help", "/help/guide", "#first-steps")
    end

    it "leaves links out of the app alone" do
      expect(hrefs).to include("https://example.com/docs")
    end

    it "points images at their help URLs" do
      expect(html.at_css("img")["src"]).to eq("/help/guide/images/diagram.png")
    end

    it "gives headings anchors" do
      expect(html.at_css("h2")["id"]).to eq("first-steps")
    end

    context "with a link from a directory's index" do
      let(:page) { described_class.find("") }

      it { expect(hrefs).to include("/help/guide", "/help/guide/setup#first-steps") }
    end

    context "with a current URL" do
      let(:page) { described_class.sidebar }
      let(:current) { "/help/guide/setup" }

      it { expect(html.css("[aria-current=page]").map { it["href"] }).to eq([current]) }
    end
  end

  # Not the fixtures: the real help/, so a renamed page can't strand a link.
  describe "the shipped help pages" do
    let(:fixtures) { Rails.root.join("help") }
    let(:pages) do
      Dir.glob("**/*.md", base: fixtures).map { described_class.new(it) }
    end
    let(:links) do
      pages.flat_map do |page|
        Nokogiri::HTML5.fragment(page.html).css("a[href^='/help']").map { it["href"].split("#").first }
      end
    end

    it "link only to pages that exist" do
      expect(links.reject { described_class.find(it.delete_prefix("/help").delete_prefix("/")) }).to be_empty
    end
  end
end
