require "rails_helper"

RSpec.describe Archyve::Keys do
  subject(:keys) { described_class.new(path, env:) }

  let(:dir) { Pathname(Dir.mktmpdir) }
  let(:path) { dir.join("archyve.yml") }
  let(:env) { {} }
  let(:name) { "SECRET_KEY_BASE" }

  after { FileUtils.remove_entry(dir) }

  describe "#[]" do
    let(:result) { keys[name] }

    it "generates a key" do
      expect(result).to match(/\A\h{128}\z/)
    end

    it "stores every key" do
      result
      expect(YAML.safe_load_file(path).keys).to match_array(described_class::GENERATORS.keys)
    end

    it "keeps the file private" do
      result
      expect(path.stat.mode & 0o777).to eq(0o600)
    end

    it "leaves no draft behind" do
      result
      expect(dir.children).to eq([path])
    end

    context "with the variable in the environment" do
      let(:env) { { name => "from-env" } }

      it { expect(result).to eq("from-env") }

      it "doesn't create a key file" do
        result
        expect(path).not_to exist
      end
    end

    context "with a key file already there" do
      before { path.write({ name => "stored" }.to_yaml) }

      it { expect(result).to eq("stored") }
    end

    context "when another process creates the file first" do
      before do
        allow(File).to receive(:link).and_wrap_original do |link, *args|
          path.write({ name => "winner" }.to_yaml)
          link.call(*args)
        end
      end

      it { expect(result).to eq("winner") }
    end

    context "when the directory doesn't exist" do
      let(:path) { dir.join("missing/archyve.yml") }

      it { expect { result }.to raise_error(/No key file at .*missing.*set SECRET_KEY_BASE/) }
    end
  end
end
