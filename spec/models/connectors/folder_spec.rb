require "rails_helper"

RSpec.describe Connectors::Folder do
  subject(:connector) { build(:folder_connector, path: root) }

  let(:root) { Dir.mktmpdir("archyve-folder-spec") }

  def write(relative, content: "hello", mtime: nil)
    absolute = File.join(root, relative)
    FileUtils.mkdir_p(File.dirname(absolute))
    File.write(absolute, content)
    File.utime(mtime, mtime, absolute) if mtime
    absolute
  end

  after { FileUtils.remove_entry(root) }

  describe "validations" do
    context "with an absolute path to a readable directory" do
      it { expect(connector).to be_valid }
    end

    context "with a relative path" do
      subject(:connector) { build(:folder_connector, path: "documents") }

      it "rejects it" do
        connector.valid?
        expect(connector.errors[:path]).to include("must be an absolute path")
      end
    end

    context "with a path that does not exist" do
      subject(:connector) { build(:folder_connector, path: "/nonexistent/archyve") }

      it "rejects it" do
        connector.valid?
        expect(connector.errors[:path]).to include("is not a directory Archyve can see")
      end
    end

    context "with a path to a file rather than a directory" do
      subject(:connector) { build(:folder_connector, path: write("a-file.md")) }

      it "rejects it" do
        connector.valid?
        expect(connector.errors[:path]).to include("is not a directory Archyve can see")
      end
    end

    context "with a sync interval below one minute" do
      subject(:connector) { build(:folder_connector, path: root, sync_interval_minutes: 0) }

      it { expect(connector).not_to be_valid }
    end
  end

  describe "#sync_interval" do
    context "with a configured interval" do
      subject(:connector) { build(:folder_connector, path: root, sync_interval_minutes: 15) }

      it { expect(connector.sync_interval).to eq(15.minutes) }
    end

    context "with no configured interval" do
      subject(:connector) { build(:folder_connector, path: root, sync_interval_minutes: nil) }

      it "falls back to the default" do
        expect(connector.sync_interval).to eq(described_class::DEFAULT_SYNC_INTERVAL_MINUTES.minutes)
      end
    end
  end

  describe "#each_item" do
    let(:result) { connector.each_item.to_a }

    context "with supported files at the top level" do
      before { write("report.md") }

      it "yields one item per file" do
        expect(result.map(&:external_id)).to eq(["report.md"])
      end

      it "titles the item with the file's basename" do
        expect(result.first.title).to eq("report.md")
      end

      it "detects the content type" do
        expect(result.first.content_type).to eq("text/markdown")
      end
    end

    context "with files in subdirectories" do
      before { write("2026/q1/notes.md") }

      it "identifies them by path relative to the root" do
        expect(result.map(&:external_id)).to eq(["2026/q1/notes.md"])
      end
    end

    context "with an unsupported extension" do
      before do
        write("keep.md")
        write("ignore.sqlite3")
      end

      it "ignores it rather than failing" do
        expect(result.map(&:external_id)).to eq(["keep.md"])
      end
    end

    context "with a dotfile" do
      before do
        write("keep.md")
        write(".hidden.md")
      end

      it "skips it" do
        expect(result.map(&:external_id)).to eq(["keep.md"])
      end
    end

    context "with a dotfile whose extension would otherwise qualify" do
      before { write(".env.md", content: "SECRET_KEY=hunter2") }

      it "never reports it" do
        expect(result).to be_empty
      end
    end

    context "with a document inside a hidden directory" do
      before { write(".git/notes.md") }

      it "does not descend into it" do
        expect(result).to be_empty
      end
    end

    context "with an empty file" do
      before { write("empty.md", content: "") }

      it "skips it" do
        expect(result).to be_empty
      end
    end

    context "with a file larger than the size limit" do
      before do
        write("big.md")
        allow(described_class).to receive(:max_file_size).and_return(1)
      end

      it "still reports it, so lowering the limit doesn't tombstone documents" do
        expect(result.map(&:external_id)).to eq(["big.md"])
      end

      it "marks it skipped rather than ingestable" do
        expect(result.first).to be_skipped
      end

      it "says why" do
        expect(result.first.skip_reason).to include("limit")
      end
    end

    context "with a file within the size limit" do
      before { write("small.md") }

      it "is not skipped" do
        expect(result.first).not_to be_skipped
      end
    end

    context "with a symlink to a file outside the root" do
      let(:outside) { Dir.mktmpdir("archyve-outside") }

      before do
        File.write(File.join(outside, "secret.md"), "secret")
        File.symlink(File.join(outside, "secret.md"), File.join(root, "link.md"))
      end

      after { FileUtils.remove_entry(outside) }

      it "does not follow it" do
        expect(result).to be_empty
      end
    end

    context "with an unchanged file scanned twice" do
      before { write("stable.md", mtime: Time.zone.parse("2026-01-01 12:00").to_time) }

      it "reports the same version token" do
        expect(connector.each_item.to_a.first.version).to eq(result.first.version)
      end
    end

    context "with a file whose contents changed" do
      let(:first_version) { result.first.version }

      before { write("changing.md", content: "one", mtime: Time.zone.parse("2026-01-01 12:00").to_time) }

      it "reports a different version token" do
        first_version
        write("changing.md", content: "two much longer content", mtime: Time.zone.parse("2026-02-01 12:00").to_time)
        expect(connector.each_item.to_a.first.version).not_to eq(first_version)
      end
    end
  end

  describe ".max_file_size" do
    context "with no override configured" do
      it "defaults to 100MB" do
        expect(described_class.max_file_size).to eq(100.megabytes)
      end
    end

    context "with an override in the environment" do
      before { allow(ENV).to receive(:fetch).with("ARCHYVE_MAX_FILE_SIZE_MB", "100").and_return("5") }

      it "uses it" do
        expect(described_class.max_file_size).to eq(5.megabytes)
      end
    end
  end

  describe "#read" do
    context "with an item inside the root" do
      before { write("readable.md", content: "the bytes") }

      it "returns its bytes" do
        expect(connector.read("readable.md")).to eq("the bytes")
      end
    end

    context "with an external_id that escapes the root" do
      it "refuses to read it" do
        expect { connector.read("../../etc/passwd") }.to raise_error(described_class::OutsideRootError)
      end
    end
  end
end
