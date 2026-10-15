require "rails_helper"

RSpec.describe Sources::Nextcloud do
  subject(:source) { build(:nextcloud_source, endpoint:, folders: ["Documents"]) }

  let(:endpoint) { create(:nextcloud_endpoint, base_url: "https://cloud.test", username: "archyve") }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:root) { "/remote.php/dav/files/archyve" }

  before do
    allow(endpoint).to receive(:client).and_return(
      Faraday.new(url: endpoint.base_url) { |f| f.adapter(:test, stubs) }
    )
  end

  # One entry in a stubbed listing. `path` is relative to the DAV root, the way
  # the source thinks of it.
  def entry(path, collection: false, size: 1024, etag: "etag-#{path}", content_type: "application/pdf", fileid: "1")
    file_props = if collection
      ""
    else
      "<d:getcontenttype>#{content_type}</d:getcontenttype><d:getcontentlength>#{size}</d:getcontentlength>"
    end

    <<~XML
      <d:response>
        <d:href>#{root}/#{path.split("/").map { |s| ERB::Util.url_encode(s) }.join("/")}#{"/" if collection}</d:href>
        <d:propstat>
          <d:prop>
            <d:resourcetype>#{"<d:collection/>" if collection}</d:resourcetype>
            <d:getetag>&quot;#{etag}&quot;</d:getetag>
            <oc:fileid>#{fileid}</oc:fileid>
            #{file_props}
          </d:prop>
          <d:status>HTTP/1.1 200 OK</d:status>
        </d:propstat>
      </d:response>
    XML
  end

  # Stubs a Depth-1 listing of `at`: its own entry first, then its children.
  def stub_listing(at, children)
    body = <<~XML
      <?xml version="1.0"?>
      <d:multistatus xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns">
        #{entry(at, collection: true, fileid: "dir")}#{children.join}
      </d:multistatus>
    XML

    path = [root, *at.split("/").map { |s| ERB::Util.url_encode(s) }].join("/")
    stubs.send(:new_stub, :propfind, path) { [207, { "Content-Type" => "application/xml" }, body] }
  end

  describe "validations" do
    context "with a Nextcloud endpoint and a folder" do
      it { expect(source).to be_valid }
    end

    context "with no endpoint" do
      subject(:source) { build(:nextcloud_source, endpoint: nil) }

      it { expect(source).not_to be_valid }
    end

    # The config a source holds means nothing against the wrong kind of server.
    context "with an endpoint of another type" do
      subject(:source) { build(:nextcloud_source, endpoint: build(:bookstack_endpoint)) }

      it "rejects it" do
        source.valid?
        expect(source.errors[:endpoint]).to include(a_string_including("Nextcloud"))
      end
    end

    context "with no folders" do
      subject(:source) { build(:nextcloud_source, folders: []) }

      it "is invalid, since a source selecting nothing would tombstone everything" do
        expect(source).not_to be_valid
      end
    end

    context "with a folder climbing out of the DAV root" do
      subject(:source) { build(:nextcloud_source, folders: ["Documents/../../etc"]) }

      it "rejects it" do
        source.valid?
        expect(source.errors[:folders]).to be_present
      end
    end
  end

  describe "#folders=" do
    context "with slashes and blanks around the edges" do
      subject(:source) { build(:nextcloud_source, folders: ["/Documents/", "", "  Policies  ", "Documents"]) }

      # One spelling per folder, so `/Documents/` and `Documents` are the same
      # selection rather than two listings of the same tree.
      it "normalizes and deduplicates" do
        expect(source.folders).to eq(["Documents", "Policies"])
      end
    end
  end

  describe "#each_item" do
    let(:result) { source.each_item.to_a }

    context "with nested folders" do
      before do
        stub_listing("Documents", [
          entry("Documents/onboarding.pdf", size: 2048, etag: "aaa", fileid: "7"),
          entry("Documents/Handbook", collection: true, fileid: "9")
        ])
        stub_listing("Documents/Handbook", [entry("Documents/Handbook/joining.md", content_type: "text/markdown", fileid: "11")])
      end

      it "descends into subfolders" do
        expect(result.map(&:external_id)).to contain_exactly(
          "Documents/onboarding.pdf", "Documents/Handbook/joining.md"
        )
      end

      it "describes a file by its etag, name and place" do
        item = result.find { |i| i.external_id == "Documents/onboarding.pdf" }

        expect(item).to have_attributes(
          version: "aaa",
          title: "onboarding.pdf",
          content_type: "application/pdf",
          byte_size: 2048,
          path: "Documents",
          url: "https://cloud.test/f/7",
          metadata: { "fileid" => "7" },
          skip_reason: nil
        )
      end

      it "records the subfolder in the nested file's path" do
        item = result.find { |i| i.external_id == "Documents/Handbook/joining.md" }

        expect(item.path).to eq("Documents/Handbook")
      end
    end

    context "with a file Docling can't read" do
      before do
        stub_listing("Documents", [
          entry("Documents/notes.md", content_type: "text/markdown"),
          entry("Documents/holiday.jpg", content_type: "image/jpeg"),
          entry("Documents/.DS_Store", content_type: "application/octet-stream")
        ])
      end

      # Passed over silently: a folder is allowed to hold things that aren't
      # documents, and reporting every photo as a problem would be noise.
      it "passes it over" do
        expect(result.map(&:external_id)).to eq(["Documents/notes.md"])
      end
    end

    context "with an empty file" do
      before { stub_listing("Documents", [entry("Documents/empty.md", size: 0)]) }

      it "passes it over" do
        expect(result).to be_empty
      end
    end

    context "with a file over the size limit" do
      before do
        allow(Source).to receive(:max_file_size).and_return(1)
        stub_listing("Documents", [entry("Documents/huge.pdf", size: 2048)])
      end

      # Still reported, with a reason. The limit is configurable and anything
      # missing from a scan gets tombstoned, so omitting these would make
      # lowering the limit delete documents whose files never moved.
      it "reports it with a skip reason rather than omitting it" do
        expect(result.map(&:skip_reason)).to match([a_string_including("limit")])
      end
    end

    context "with one folder nested inside another selected folder" do
      subject(:source) { build(:nextcloud_source, endpoint:, folders: ["Documents", "Documents/Handbook"]) }

      before do
        stub_listing("Documents", [entry("Documents/Handbook", collection: true)])
        stub_listing("Documents/Handbook", [entry("Documents/Handbook/joining.md", content_type: "text/markdown")])
      end

      # Both selections reach the same file, and yielding it twice would have the
      # sync engine reconcile one document against itself.
      it "yields each file once" do
        expect(result.map(&:external_id)).to eq(["Documents/Handbook/joining.md"])
      end
    end

    context "with a file whose name needs escaping" do
      before { stub_listing("Documents", [entry("Documents/Q1 report.pdf")]) }

      it "reads the unescaped path back" do
        expect(result.map(&:external_id)).to eq(["Documents/Q1 report.pdf"])
      end
    end

    # An unreachable server has to fail the run, not report an empty source:
    # Sources::Sync only tombstones a scan that reached the end, so a raise here
    # is what keeps a server outage from retiring the whole archive.
    context "when the server can't be reached" do
      before do
        allow(endpoint).to receive(:client).and_return(
          Faraday.new(url: endpoint.base_url) do |f|
            f.response :raise_error
            f.adapter(:test, stubs)
          end
        )
        stubs.send(:new_stub, :propfind, "#{root}/Documents") { [503, {}, ""] }
      end

      it "raises rather than enumerating nothing" do
        expect { result }.to raise_error(Faraday::ServerError)
      end
    end
  end

  describe "#read" do
    let(:result) { source.read("Documents/onboarding.pdf") }

    context "with a file on the server" do
      before { stubs.get("#{root}/Documents/onboarding.pdf") { [200, {}, "%PDF-1.7"] } }

      it { expect(result).to eq("%PDF-1.7") }
    end
  end

  describe "#catalogue" do
    context "at the root" do
      let(:result) { source.catalogue }

      before do
        stub_listing("", [
          entry("Documents", collection: true),
          entry("readme.md", content_type: "text/markdown")
        ])
      end

      # Only folders: the picker picks folders, and a listing full of files would
      # bury them.
      it "lists the folders and nothing else" do
        expect(result.directories.map(&:name)).to eq(["Documents"])
      end

      it "reports where it looked, so the form can draw a breadcrumb" do
        expect(result.at).to eq("")
      end
    end

    context "inside a folder" do
      let(:result) { source.catalogue(at: "/Documents/") }

      before { stub_listing("Documents", [entry("Documents/Handbook", collection: true)]) }

      it "normalizes the path it was given" do
        expect(result).to have_attributes(at: "Documents", error: nil)
      end

      it "lists that folder's subfolders" do
        expect(result.directories.map(&:path)).to eq(["Documents/Handbook"])
      end
    end

    context "when the server rejects the credentials" do
      let(:result) { source.catalogue }

      before do
        allow(endpoint).to receive(:client).and_return(
          Faraday.new(url: endpoint.base_url) do |f|
            f.response :raise_error
            f.adapter(:test, stubs)
          end
        )
        stubs.send(:new_stub, :propfind, root) { [401, {}, ""] }
      end

      # Recorded, not raised: the form has to render as a sentence rather than a
      # 500, the same way Endpoint#access records it.
      it "records the error instead of raising" do
        expect(result).to have_attributes(directories: [], error: a_string_including("401"))
      end
    end

    context "with no endpoint" do
      subject(:source) { build(:nextcloud_source, endpoint: nil) }

      let(:result) { source.catalogue }

      it "lists nothing without calling anything" do
        expect(result).to have_attributes(directories: [], error: nil)
      end
    end
  end

  describe "#location" do
    it "names the server, so two sources on different clouds read apart" do
      expect(source.location).to eq("cloud.test")
    end
  end

  describe "#document_url" do
    let(:document) { build(:document, source:, url: "https://cloud.test/f/7") }

    # Nextcloud's own short link, which survives the file being moved.
    it "hands the reader the live file" do
      expect(source.document_url(document)).to eq("https://cloud.test/f/7")
    end
  end
end
