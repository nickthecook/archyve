require "rails_helper"

RSpec.describe Sources::Bamboohr do
  subject(:source) { build(:bamboohr_source, endpoint:, categories: [20]) }

  let(:endpoint) { create(:bamboohr_endpoint) }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }

  let(:handbook) do
    { "id" => 387, "name" => "Handbook", "originalFileName" => "handbook.pdf", "size" => "57028",
      "dateCreated" => "2025-02-11T22:30:07+0000" }
  end
  let(:categories) do
    [{ "id" => 20, "name" => "Policies", "files" => [handbook] },
     { "id" => 21, "name" => "Payroll", "files" => [handbook.merge("id" => 400)] }]
  end
  let(:listing) { [200, { "Content-Type" => "application/json" }, { "categories" => categories }.to_json] }

  before do
    allow(endpoint).to receive(:client).and_return(
      Faraday.new(url: "https://acme.bamboohr.com") do |f|
        f.response :raise_error
        f.adapter(:test, stubs)
      end
    )

    stubs.get("/api/v1/files/view") { listing }
  end

  describe "validations" do
    context "with a BambooHR endpoint and a category" do
      it { expect(source).to be_valid }
    end

    context "with no categories" do
      subject(:source) { build(:bamboohr_source, categories: []) }

      it { expect(source).not_to be_valid }
    end

    context "with a category that isn't an id" do
      subject(:source) { build(:bamboohr_source, categories: ["Policies"]) }

      it { expect(source).not_to be_valid }
    end
  end

  describe "#categories=" do
    let(:result) { source.categories }

    # The picker submits strings, plus an empty one so unticking all clears the list.
    context "with what the picker submits" do
      subject(:source) { build(:bamboohr_source, categories: ["", "20", "21", "20"]) }

      it { expect(result).to eq([20, 21]) }
    end
  end

  describe "#each_item" do
    let(:result) { source.each_item.to_a }

    context "with files in picked and unpicked categories" do
      it "yields only files in the picked categories" do
        expect(result.map(&:external_id)).to eq(["387"])
      end

      it "describes the file by its category" do
        expect(result.first).to have_attributes(title: "Handbook", path: "Policies", byte_size: 57_028,
          content_type: "application/pdf", version: "2025-02-11T22:30:07+0000:57028")
      end

      it "keeps the original filename for extraction" do
        expect(result.first.metadata).to include("original_file_name" => "handbook.pdf")
      end
    end

    context "with a file Docling can't read" do
      let(:categories) do
        [{ "id" => 20, "name" => "Policies", "files" => [handbook.merge("originalFileName" => "photo.heic")] }]
      end

      it { expect(result).to be_empty }
    end

    context "with a file over the size limit" do
      let(:categories) do
        [{ "id" => 20, "name" => "Policies", "files" => [handbook.merge("size" => 1.gigabyte.to_s)] }]
      end

      it { expect(result.first.skip_reason).to include("limit") }
    end
  end

  describe "#read" do
    let(:result) { source.read("387") }

    before { stubs.get("/api/v1/files/387") { [200, {}, "%PDF handbook"] } }

    it { expect(result).to eq("%PDF handbook") }
  end

  describe "#catalogue" do
    let(:result) { source.catalogue }

    context "when BambooHR answers" do
      it { expect(result.categories.map(&:name)).to eq(%w[Policies Payroll]) }
    end

    context "when BambooHR refuses the key" do
      let(:listing) { [401, {}, ""] }

      it { expect(result.error).to include("Unauthorized") }
    end
  end
end
