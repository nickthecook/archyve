require "rails_helper"

RSpec.describe Crawl::Boundary do
  subject(:boundary) { described_class.new(origin: origin, prefix: prefix) }

  let(:origin) { "https://docs.test" }
  let(:prefix) { "/docs" }

  describe "#seed" do
    let(:result) { boundary.seed }

    it { expect(result).to eq("https://docs.test/docs") }

    context "with no prefix" do
      let(:prefix) { nil }

      it { expect(result).to eq("https://docs.test") }
    end

    context "with a prefix written without a leading slash" do
      let(:prefix) { "docs/" }

      it { expect(result).to eq("https://docs.test/docs") }
    end
  end

  describe "#canonicalize" do
    let(:result) { boundary.canonicalize(href, base: "https://docs.test/docs/guide") }

    context "with a fragment and a query string" do
      let(:href) { "/docs/install?variant=deb#step-2" }

      it { expect(result).to eq("https://docs.test/docs/install") }
    end

    context "with a trailing slash" do
      let(:href) { "/docs/install/" }

      it { expect(result).to eq("https://docs.test/docs/install") }
    end

    # RFC 3986: the base's last segment is a file, not a directory, so a
    # relative href replaces it. Worth pinning, because canonical URLs here
    # never carry a trailing slash and so always look like files.
    context "with a relative href" do
      let(:href) { "../install" }

      it { expect(result).to eq("https://docs.test/install") }
    end

    context "with a sibling href" do
      let(:href) { "install" }

      it { expect(result).to eq("https://docs.test/docs/install") }
    end

    context "with a mixed-case host" do
      let(:href) { "https://DOCS.test/Docs/Install" }

      it "lowercases the host and leaves the path alone" do
        expect(result).to eq("https://docs.test/Docs/Install")
      end
    end

    context "with the scheme's default port stated" do
      let(:href) { "https://docs.test:443/docs/install" }

      it { expect(result).to eq("https://docs.test/docs/install") }
    end

    context "with a link in the other scheme" do
      let(:href) { "http://docs.test/docs/install" }

      # One page, one document. A site serving both schemes would otherwise
      # hold two of everything, and its own http→https redirect would read as
      # leaving the boundary.
      it "coerces it to the origin's scheme" do
        expect(result).to eq("https://docs.test/docs/install")
      end
    end

    context "with a non-http scheme" do
      let(:href) { "mailto:someone@docs.test" }

      it { expect(result).to be_nil }
    end

    context "with a bare fragment" do
      let(:href) { "#section" }

      it { expect(result).to be_nil }
    end
  end

  describe "#include?" do
    let(:result) { boundary.include?(url) }

    context "with the prefix itself" do
      let(:url) { "https://docs.test/docs" }

      it { expect(result).to be(true) }
    end

    context "with a path under the prefix" do
      let(:url) { "https://docs.test/docs/guide/install" }

      it { expect(result).to be(true) }
    end

    # The whole reason the match is segment-aware rather than a string prefix.
    context "with a path that merely starts with the prefix's letters" do
      let(:url) { "https://docs.test/docsearch" }

      it { expect(result).to be(false) }
    end

    context "with another host" do
      let(:url) { "https://elsewhere.test/docs/guide" }

      it { expect(result).to be(false) }
    end

    context "with no prefix configured" do
      let(:prefix) { nil }
      let(:url) { "https://docs.test/anything" }

      it { expect(result).to be(true) }
    end
  end

  describe "#resolve" do
    let(:result) { boundary.resolve(href, base: "https://docs.test/docs/guide") }

    context "with a link inside the boundary" do
      let(:href) { "install/?from=nav" }

      it { expect(result).to eq("https://docs.test/docs/install") }
    end

    context "with a link outside the prefix" do
      let(:href) { "/blog/announcement" }

      it { expect(result).to be_nil }
    end

    context "with a link to another site" do
      let(:href) { "https://elsewhere.test/docs/guide" }

      it { expect(result).to be_nil }
    end
  end
end
