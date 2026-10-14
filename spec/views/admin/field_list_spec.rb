require "rails_helper"

RSpec.describe Views::Admin::FieldList do
  subject(:component) { described_class.new(record:, fields:) }

  let(:result) { component.call }
  let(:record) { Struct.new(:url, :body).new("http://example.test", { "model" => "llama3.2" }) }
  let(:fields) do
    [
      Views::Admin::Field.new("URL", mono: true) { |row| row.url },
      Views::Admin::Field.new("Body") { |row| component.render Views::Admin::Json.new(value: row.body) }
    ]
  end

  describe "#call" do
    it "labels each field" do
      expect(result).to include(">URL<", ">Body<")
    end

    it "prints a String a field's block returns" do
      expect(result).to include("http://example.test")
    end

    it "sets a mono field's value in mono" do
      expect(result).to include("font-mono tabular-nums")
    end

    # A field is free to render instead of returning — a JSON disclosure can't
    # be a String.
    it "leaves a field that rendered itself alone" do
      expect(result).to include("llama3.2", "<details")
    end
  end
end
