require "rails_helper"

RSpec.describe Views::Admin::Table do
  subject(:component) { described_class.new(rows:, fields:, href:) }

  let(:result) { component.call }
  let(:rows) { [Struct.new(:name, :size).new("first", 12)] }
  let(:href) { nil }
  let(:fields) do
    [
      Views::Admin::Field.new("Name") { |record| record.name },
      Views::Admin::Field.new("Size", numeric: true) { |record| record.size.to_s }
    ]
  end

  describe "#call" do
    it "heads each column" do
      expect(result).to include(">Name<", ">Size<")
    end

    it "prints a String a field's block returns" do
      expect(result).to include(">first<")
    end

    context "with a numeric field" do
      it "aligns and sets the digits in mono" do
        expect(result).to include("text-right font-mono tabular-nums")
      end
    end

    context "with a field that renders its own markup" do
      let(:fields) { [Views::Admin::Field.new("Name") { |record| Views::Admin::Empty.new(message: record.name) }] }

      it "does not also print the returned object" do
        expect(result).not_to include("Views::Admin::Empty")
      end
    end

    context "with an href" do
      let(:href) { ->(record) { "/admin/#{record.name}" } }

      it "links the first cell into the record" do
        expect(result).to include(%(<a href="/admin/first"))
      end

      it "links it once, not every cell" do
        expect(result.scan("<a href").size).to eq(1)
      end
    end
  end
end
