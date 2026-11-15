require "rails_helper"

RSpec.describe Sources::Sharepoint do
  subject(:source) { build(:sharepoint_source, endpoint:, drive_id: "drive-1", folders:) }

  let(:endpoint) { create(:sharepoint_endpoint) }
  let(:folders) { ["Policies"] }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }

  before { stub_graph(stubs) }

  describe "validations" do
    context "with a SharePoint endpoint, a library and a folder" do
      it { expect(source).to be_valid }
    end

    context "with an endpoint of another type" do
      let(:endpoint) { build(:nextcloud_endpoint) }

      it { expect(source).not_to be_valid }
    end

    context "with no library" do
      before { source.drive_id = nil }

      it { expect(source).not_to be_valid }
    end

    context "with no folders" do
      let(:folders) { [] }

      it { expect(source).not_to be_valid }
    end

    context "with a folder climbing out of the library" do
      let(:folders) { ["Policies/../.."] }

      it { expect(source).not_to be_valid }
    end
  end

  describe "#folders=" do
    let(:folders) { ["/Policies/", "", "Policies", "HR/Benefits"] }

    it "normalizes slashes and drops blanks and duplicates" do
      expect(source.folders).to eq(["Policies", "HR/Benefits"])
    end
  end

  describe "#each_item" do
    let(:result) { source.each_item.to_a }

    before do
      stub_graph_get(stubs, "drives/drive-1/root:/Policies:/children", value: [
        graph_folder("2026"),
        graph_file("handbook.pdf"),
        graph_file("logo.png"),
        graph_file("empty.docx", size: 0)
      ])
      stub_graph_get(stubs, "drives/drive-1/root:/Policies/2026:/children", value: [graph_file("travel.docx")])
    end

    context "with one folder holding a subfolder" do
      it "yields the eligible files, subfolders included" do
        expect(result.map(&:title)).to eq(["handbook.pdf", "travel.docx"])
      end

      it "keys each by Graph's item id, so a move isn't a new document" do
        expect(result.first).to have_attributes(external_id: "file-handbook.pdf", version: "ctag-handbook.pdf")
      end

      it "describes where the file sits and how to open it" do
        expect(result.last).to have_attributes(
          path: "Policies/2026",
          url: "https://example.sharepoint.com/sites/Team/travel.docx",
          metadata: { "modified_at" => "2026-11-01T10:00:00Z" }
        )
      end
    end

    # A folder and its own subfolder both picked: everything under the inner one
    # is reached twice, and must be yielded once.
    context "with a folder and its subfolder both picked" do
      let(:folders) { ["Policies", "Policies/2026"] }

      it { expect(result.map(&:external_id).tally.values).to all(eq(1)) }
    end

    context "with a folder name needing escaping" do
      let(:folders) { ["HR & Benefits"] }

      before { stub_graph_get(stubs, "drives/drive-1/root:/HR%20%26%20Benefits:/children", value: [graph_file("plan.pdf")]) }

      it { expect(result.map(&:title)).to eq(["plan.pdf"]) }
    end

    # Pages come as an absolute nextLink, which has to be followed as given.
    context "with a folder spanning two pages" do
      let(:folders) { ["Archive"] }

      before do
        stub_graph_get(stubs, "drives/drive-1/root:/Archive:/children",
          value: [graph_file("a.pdf")], "@odata.nextLink": "https://graph.microsoft.com/v1.0/next-page")
        stub_graph_get(stubs, "next-page", value: [graph_file("b.pdf")])
      end

      it { expect(result.map(&:title)).to eq(["a.pdf", "b.pdf"]) }
    end

    # Not swallowed: a scan that silently stopped would tombstone every file it
    # never reached.
    context "when a picked folder has gone" do
      let(:folders) { ["Renamed"] }

      before do
        stub_graph_get(stubs, "drives/drive-1/root:/Renamed:/children",
          { error: { code: "itemNotFound", message: "The resource could not be found." } }, status: 404)
      end

      it { expect { result }.to raise_error(Endpoints::Sharepoint::Error, /itemNotFound/) }
    end
  end

describe "#read" do
  let(:result) { source.read("file-1") }
  let(:download_url) do
    "https://download.test/_layouts/15/download.aspx?UniqueId=a3a3&Translate=false&tempauth=v1.ab+c%2Fd~e&ApiVersion=2.0"
  end
  let(:sent) { [] }

  before do
    stub_graph_get(stubs, "drives/drive-1/items/file-1", "@microsoft.graph.downloadUrl": download_url)
    stubs.get("https://download.test/_layouts/15/download.aspx") do |env|
      sent << env.url.to_s
      [200, {}, "%PDF-1.7"]
    end
  end

  it { expect(result).to eq("%PDF-1.7") }

  # SharePoint answers 401 to its own download URL once the query has been
  # reordered or re-escaped.
  it "requests the download URL exactly as Graph wrote it" do
    result
    expect(sent).to eq([download_url])
  end
end

  describe "#catalogue" do
    let(:result) { source.catalogue }
    let(:drives_status) { 200 }
    let(:drives_body) do
      { value: [
        { id: "drive-1", name: "Documents", webUrl: "https://example.sharepoint.com/sites/Team/Shared%20Documents" },
        { id: "drive-2", name: "Preservation Hold Library",
          webUrl: "https://example.sharepoint.com/sites/Team/PreservationHoldLibrary" }
      ] }
    end

    before do
      stub_graph_get(stubs, "sites/example.sharepoint.com:/sites/Team:/drives", drives_body, status: drives_status)
      stub_graph_get(stubs, "drives/drive-1/root/children", value: [graph_folder("Policies"), graph_file("readme.pdf")])
    end

    context "at the library's root" do
      it "lists the folders and nothing else" do
        expect(result.directories.map(&:name)).to eq(["Policies"])
      end

      it "leaves out the Preservation Hold Library" do
        expect(result.drives.map(&:name)).to eq(["Documents"])
      end
    end

    context "before a library is chosen" do
      before { source.drive_id = nil }

      it "lists the site's first library" do
        expect(result).to have_attributes(drive_id: "drive-1", error: nil)
      end
    end

    context "when Graph refuses the app" do
      let(:drives_status) { 403 }
      let(:drives_body) { { error: { code: "accessDenied", message: "Access denied" } } }

      it "records the reason rather than raising" do
        expect(result.error).to include("accessDenied: Access denied")
      end
    end
  end

  describe "#filename_for" do
    let(:document) { build(:document, external_id: "01ABCDEF", title: "handbook.pdf") }

    it "names the file after its title, since the id has no extension for Docling" do
      expect(source.filename_for(document)).to eq("handbook.pdf")
    end
  end
end
