RSpec.describe Parsers do
  subject { described_class }

  shared_examples "supported_format_parser_by_filename" do |file_ext, parser_class|
    context "with a #{file_ext} document" do
      let(:filename) { "something#{file_ext}" }

      it "succeeds" do
        expect(subject.parser_for(filename)).to be(parser_class)
      end
    end
  end

  shared_examples "supported_format_parser_by_content_type" do |content_type, parser_class|
    context "with a #{content_type} document" do
      let(:filename) { "something.98384" }

      it "succeeds" do
        expect(subject.parser_for(filename, content_type)).to be(parser_class)
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

    # include_examples "supported_format_parser_by_filename", ".pdf", Parsers::Pdf
    include_examples "supported_format_parser_by_filename", ".docx", Parsers::Docx
    include_examples "supported_format_parser_by_filename", ".md", Parsers::CommonMark
    include_examples "supported_format_parser_by_filename", ".txt", Parsers::Text
    include_examples "supported_format_parser_by_filename", ".html", Parsers::HtmlViaMarkdown

    # include_examples "supported_format_parser_by_content_type", "application/pdf", Parsers::Pdf
    include_examples "supported_format_parser_by_content_type", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", Parsers::Docx
    include_examples "supported_format_parser_by_content_type", "text/markdown", Parsers::CommonMark
    include_examples "supported_format_parser_by_content_type", "text/plain", Parsers::Text
    include_examples "supported_format_parser_by_content_type", "application/html", Parsers::HtmlViaMarkdown
  end
end
