require "rails_helper"

RSpec.describe Sources::Bookstack do
  subject(:source) { build(:bookstack_source, endpoint:, selectors: [{ "book" => 1 }]) }

  let(:endpoint) { create(:bookstack_endpoint, base_url: "https://wiki.test") }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }

  # The pages, books and chapters a stubbed wiki reports. Overridden per context.
  let(:books) { [{ "id" => 1, "name" => "Handbook", "slug" => "handbook", "description" => "How we work" }] }
  let(:chapters) { [] }
  let(:pages) do
    [{ "id" => 7, "name" => "Onboarding", "slug" => "onboarding", "book_id" => 1, "chapter_id" => 0,
       "updated_at" => "2026-09-01T10:00:00.000000Z" }]
  end

  # What the wiki reports as its page count — more than `pages` only where a
  # context is exercising pagination.
  let(:page_total) { pages.size }

  def stub_list(path, records, offset: 0, total: nil)
    stubs.get("#{path}?count=500&offset=#{offset}") do
      [200, { "Content-Type" => "application/json" },
       { "data" => records, "total" => total || records.size }.to_json]
    end
  end

  before do
    allow(endpoint).to receive(:client).and_return(Faraday.new { |f| f.adapter(:test, stubs) })

    stub_list("/api/books", books)
    stub_list("/api/chapters", chapters)
    stub_list("/api/pages", pages, total: page_total)
  end

  describe "validations" do
    context "with a BookStack endpoint and a selector" do
      it { expect(source).to be_valid }
    end

    context "with no endpoint" do
      subject(:source) { build(:bookstack_source, endpoint: nil) }

      it "is invalid" do
        expect(source).not_to be_valid
      end
    end

    # The config a source holds means nothing against the wrong kind of server,
    # and Endpoint is an STI base with more types to come.
    context "with an endpoint of another type" do
      subject(:source) { build(:bookstack_source, endpoint: Endpoint.new(name: "Something else")) }

      it "rejects it" do
        source.valid?
        expect(source.errors[:endpoint]).to include(a_string_including("BookStack"))
      end
    end

    context "with no selectors" do
      subject(:source) { build(:bookstack_source, selectors: []) }

      it "is invalid, since a source selecting nothing would tombstone everything" do
        expect(source).not_to be_valid
      end
    end

    context "with a selector naming something that isn't a container" do
      subject(:source) { build(:bookstack_source, selectors: [{ "page" => 4 }]) }

      it "rejects it" do
        source.valid?
        expect(source.errors[:selectors]).to include(a_string_including("shelf, book or chapter"))
      end
    end
  end

  describe "#each_item" do
    let(:result) { source.each_item.to_a }

    context "with a page in a selected book" do
      it "yields it keyed by page id, so a page that moves stays the same document" do
        expect(result.map(&:external_id)).to eq(["7"])
      end

      it "titles it with the page name" do
        expect(result.first.title).to eq("Onboarding")
      end

      it "takes the markdown export's content type" do
        expect(result.first.content_type).to eq("text/markdown")
      end

      it "paths it by its book" do
        expect(result.first.path).to eq("Handbook")
      end

      it "records a followable address" do
        expect(result.first.url).to eq("https://wiki.test/books/handbook/page/onboarding")
      end

      # Never embedded — see docs/todo.md. Stored so the UI can show it.
      it "carries the book's description as metadata" do
        expect(result.first.metadata).to include("book" => "Handbook", "book_description" => "How we work")
      end
    end

    context "with a page in a chapter of a selected book" do
      let(:chapters) { [{ "id" => 3, "name" => "Joining", "book_id" => 1, "description" => "First week" }] }
      let(:pages) do
        [{ "id" => 7, "name" => "Onboarding", "slug" => "onboarding", "book_id" => 1, "chapter_id" => 3,
           "updated_at" => "2026-09-01T10:00:00.000000Z" }]
      end

      it "paths it through book and chapter" do
        expect(result.first.path).to eq("Handbook/Joining")
      end

      it "carries the chapter's description too" do
        expect(result.first.metadata).to include("chapter" => "Joining", "chapter_description" => "First week")
      end
    end

    context "with a page in a book that wasn't selected" do
      let(:books) do
        [
          { "id" => 1, "name" => "Handbook", "slug" => "handbook" },
          { "id" => 2, "name" => "Private", "slug" => "private" }
        ]
      end
      let(:pages) do
        [
          { "id" => 7, "name" => "Onboarding", "slug" => "onboarding", "book_id" => 1, "chapter_id" => 0,
            "updated_at" => "2026-09-01T10:00:00.000000Z" },
          { "id" => 8, "name" => "Secrets", "slug" => "secrets", "book_id" => 2, "chapter_id" => 0,
            "updated_at" => "2026-09-01T10:00:00.000000Z" }
        ]
      end

      it "leaves it out" do
        expect(result.map(&:external_id)).to eq(["7"])
      end
    end

    context "with a chapter selector" do
      subject(:source) { build(:bookstack_source, endpoint:, selectors: [{ "chapter" => 3 }]) }

      let(:chapters) { [{ "id" => 3, "name" => "Joining", "book_id" => 1 }] }
      let(:pages) do
        [
          { "id" => 7, "name" => "Onboarding", "slug" => "onboarding", "book_id" => 1, "chapter_id" => 3,
            "updated_at" => "2026-09-01T10:00:00.000000Z" },
          { "id" => 9, "name" => "Elsewhere", "slug" => "elsewhere", "book_id" => 1, "chapter_id" => 0,
            "updated_at" => "2026-09-01T10:00:00.000000Z" }
        ]
      end

      it "takes only that chapter's pages, not the whole book's" do
        expect(result.map(&:external_id)).to eq(["7"])
      end
    end

    # One extra call per selected shelf, not per shelf in the wiki: a shelf's
    # books are only on the shelf's own record.
    context "with a shelf selector" do
      subject(:source) { build(:bookstack_source, endpoint:, selectors: [{ "shelf" => 5 }]) }

      before do
        stubs.get("/api/shelves/5") do
          [200, { "Content-Type" => "application/json" }, { "id" => 5, "books" => [{ "id" => 1 }] }.to_json]
        end
      end

      it "takes the pages of the books on it" do
        expect(result.map(&:external_id)).to eq(["7"])
      end
    end

    context "with a draft" do
      let(:pages) do
        [{ "id" => 7, "name" => "Half a thought", "slug" => "half", "book_id" => 1, "chapter_id" => 0,
           "draft" => true, "updated_at" => "2026-09-01T10:00:00.000000Z" }]
      end

      it "passes over it silently" do
        expect(result).to be_empty
      end
    end

    context "with a template" do
      let(:pages) do
        [{ "id" => 7, "name" => "Meeting notes", "slug" => "notes", "book_id" => 1, "chapter_id" => 0,
           "template" => true, "updated_at" => "2026-09-01T10:00:00.000000Z" }]
      end

      it "passes over it silently" do
        expect(result).to be_empty
      end
    end

    context "with more pages than fit in one request" do
      let(:pages) do
        Array.new(described_class::PAGE_SIZE) do |i|
          { "id" => i + 1, "name" => "Page #{i + 1}", "slug" => "p#{i + 1}", "book_id" => 1, "chapter_id" => 0,
            "updated_at" => "2026-09-01T10:00:00.000000Z" }
        end
      end
      let(:page_total) { described_class::PAGE_SIZE + 1 }

      before do
        stub_list("/api/pages", [{ "id" => page_total, "name" => "Last", "slug" => "last", "book_id" => 1,
                                   "chapter_id" => 0, "updated_at" => "2026-09-01T10:00:00.000000Z" }],
          offset: described_class::PAGE_SIZE, total: page_total)
      end

      it "pages through the whole list" do
        expect(result.size).to eq(page_total)
      end
    end

    context "with the same page scanned twice, unedited" do
      it "reports the same version token" do
        expect(source.each_item.to_a.first.version).to eq(result.first.version)
      end
    end

    # The token is the revision marker alone. A book rename moves the path of
    # every page in it; refetching all of them to learn the bytes are identical
    # is exactly what this avoids — Sources::Sync rewrites the path instead.
    context "with the book renamed but the page untouched" do
      it "reports an unchanged version token, and a new path" do
        before_rename = result.first
        books.first["name"] = "Field Guide"

        after_rename = source.each_item.to_a.first
        expect(after_rename.version).to eq(before_rename.version)
        expect(after_rename.path).to eq("Field Guide")
      end
    end
  end

  describe "#read" do
    before do
      stubs.get("/api/pages/7/export/markdown") { [200, {}, "# Onboarding\n"] }
    end

    it "returns the author's markdown, not rendered HTML" do
      expect(source.read("7")).to eq("# Onboarding\n")
    end
  end

  describe "#filename_for" do
    # The external_id is a page id, and Docling picks its reader off the
    # extension — "7" would arrive as an unknown format.
    it "names the bytes after the title, with a markdown extension" do
      document = build(:document, source:, external_id: "7", title: "Onboarding & you")

      expect(source.filename_for(document)).to eq("onboarding-you.md")
    end
  end

  describe "#ocr?" do
    # The markdown export carries image links, not images.
    it "is off, whatever the config says" do
      source.ocr = true

      expect(source.ocr?).to be(false)
    end
  end
end
