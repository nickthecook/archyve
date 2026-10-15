require "rails_helper"

RSpec.describe Nextcloud::Dav do
  subject(:dav) { described_class.new(endpoint) }

  let(:endpoint) { create(:nextcloud_endpoint, base_url: "https://cloud.test", username: "archyve") }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:root) { "/remote.php/dav/files/archyve" }

  before do
    allow(endpoint).to receive(:client).and_return(Faraday.new { |f| f.adapter(:test, stubs) })
  end

  # One `d:response` as Nextcloud writes them: a 200 propstat for what it has and
  # a 404 propstat for what it couldn't supply.
  def response_for(href, collection: false, size: 1024, etag: "abc123", content_type: "application/pdf",
    fileid: "42")
    missing = collection ? "<d:getcontenttype/><d:getcontentlength/>" : ""
    present = if collection
      ""
    else
      "<d:getcontenttype>#{content_type}</d:getcontenttype>" \
        "<d:getcontentlength>#{size}</d:getcontentlength>"
    end

    <<~XML
      <d:response>
        <d:href>#{href}</d:href>
        <d:propstat>
          <d:prop>
            <d:resourcetype>#{"<d:collection/>" if collection}</d:resourcetype>
            <d:getetag>&quot;#{etag}&quot;</d:getetag>
            <d:getlastmodified>Tue, 14 Oct 2026 09:00:00 GMT</d:getlastmodified>
            <oc:fileid>#{fileid}</oc:fileid>
            #{present}
          </d:prop>
          <d:status>HTTP/1.1 200 OK</d:status>
        </d:propstat>
        <d:propstat>
          <d:prop>#{missing}</d:prop>
          <d:status>HTTP/1.1 404 Not Found</d:status>
        </d:propstat>
      </d:response>
    XML
  end

  def multistatus(*responses)
    <<~XML
      <?xml version="1.0"?>
      <d:multistatus xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns" xmlns:s="http://sabredav.org/ns">
        #{responses.join}
      </d:multistatus>
    XML
  end

  # Faraday's test adapter only exposes the eight standard verbs; `new_stub` is
  # the generic one behind them, and it is protected.
  def stub_propfind(path, body)
    stubs.send(:new_stub, :propfind, path) { [207, { "Content-Type" => "application/xml" }, body] }
  end

  describe "#list" do
    let(:result) { dav.list("Documents") }

    context "with a directory holding one file and one subfolder" do
      before do
        stub_propfind("#{root}/Documents", multistatus(
          response_for("#{root}/Documents/", collection: true, fileid: "1"),
          response_for("#{root}/Documents/onboarding.pdf", size: 2048, etag: "aaa", fileid: "7"),
          response_for("#{root}/Documents/Handbook/", collection: true, fileid: "9")
        ))
      end

      # The first response element is the directory we asked about, and a listing
      # that reported it would put the directory inside itself.
      it "drops the requested directory" do
        expect(result.map(&:path)).to eq(["Documents/onboarding.pdf", "Documents/Handbook"])
      end

      it "reads the file's properties" do
        file = result.first

        expect(file).to have_attributes(
          path: "Documents/onboarding.pdf",
          name: "onboarding.pdf",
          directory: false,
          size: 2048,
          etag: "aaa",
          content_type: "application/pdf",
          fileid: "7"
        )
      end

      it "recognises a collection as a directory" do
        expect(result.last).to be_directory
      end

      # A directory has no content type or length, and Nextcloud reports them in
      # a 404 propstat. Absent and empty have to read the same way.
      it "leaves a directory's file properties blank" do
        expect(result.last).to have_attributes(content_type: nil, size: 0)
      end
    end

    context "with a name needing escaping in the href" do
      before do
        stub_propfind("#{root}/Documents", multistatus(
          response_for("#{root}/Documents/", collection: true),
          response_for("#{root}/Documents/Q1%20report%20%26%20notes.pdf")
        ))
      end

      it "unescapes the path" do
        expect(result.map(&:path)).to eq(["Documents/Q1 report & notes.pdf"])
      end
    end

    context "with an href outside the endpoint's DAV root" do
      before do
        stub_propfind("#{root}/Documents", multistatus(
          response_for("#{root}/Documents/", collection: true),
          response_for("/remote.php/dav/files/someone-else/secret.pdf")
        ))
      end

      it "ignores it" do
        expect(result).to be_empty
      end
    end

    context "with a folder name needing escaping on the way out" do
      let(:result) { dav.list("Shared docs/Q1 & Q2") }

      before do
        stub_propfind("#{root}/Shared%20docs/Q1%20%26%20Q2", multistatus(
          response_for("#{root}/Shared%20docs/Q1%20%26%20Q2/", collection: true)
        ))
      end

      # Escaped per segment: a `/` separates, and escaping the whole path would
      # ask for one file whose name contains slashes.
      it "escapes each segment and keeps the separators" do
        result
        stubs.verify_stubbed_calls
      end
    end
  end

  describe "#exist?" do
    let(:result) { dav.exist? }

    context "when the root answers" do
      before do
        stub_propfind(root, multistatus(response_for("#{root}/", collection: true)))
      end

      it { expect(result).to be(true) }
    end
  end

  describe "#read" do
    let(:result) { dav.read("Documents/onboarding.pdf") }

    context "with a file on the server" do
      before do
        stubs.get("#{root}/Documents/onboarding.pdf") { [200, {}, "%PDF-1.7"] }
      end

      it { expect(result).to eq("%PDF-1.7") }
    end
  end
end
