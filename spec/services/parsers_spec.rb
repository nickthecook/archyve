RSpec.describe Parsers do
  subject { described_class }

  shared_examples "supported_format_parser" do |file_ext, parser_class|
    context "with a #{file_ext} document" do
      let(:filename) { "something#{file_ext}" }

      it "succeeds" do
        expect(subject.parser_for(filename)).to be(parser_class)
      end
    end
  end

  describe "#parser_for" do
    context "with an unsupported document format" do
      let(:filename) { 'something.xls' }

      it "causes error" do
        expect { subject.parser_for(filename) }.to raise_error(Parsers::UnsupportedFileFormat)
      end
    end

    include_examples "supported_format_parser", ".pdf", Parsers::Pdf
    include_examples "supported_format_parser", ".docx", Parsers::Docx
    include_examples "supported_format_parser", ".md", Parsers::CommonMark
    include_examples "supported_format_parser", ".txt", Parsers::Text
    include_examples "supported_format_parser", ".html", Parsers::HtmlViaMarkdown
  end
end
