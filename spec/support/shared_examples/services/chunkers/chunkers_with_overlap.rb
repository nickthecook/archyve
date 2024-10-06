RSpec.shared_examples "chunkers supporting overlap" do
  # Requires
  # - `subject` to be instance of a chunker
  # - the following `let` variables to be defined
  #   - :text
  #   - :text_type
  #   - :chunk_size
  #   - :chunk_overlap
  let(:chunking_method) { :basic }
  let(:chunking_profile) { create(:chunking_profile, method: chunking_method) }
  let(:file) { fixture_file_upload("small_doc.md", 'text/markdown; charset=UTF-8') }
  let(:document) { create(:document, state: :created, file:, chunking_profile:) }

  #let(:parser) { create(:parser, document:) }

  describe "#chunk" do
    # parser = Parsers::Text.new(document)
    # let(:chunks) { subject.chunk(parser) }

    context "with overlap" do
      it "returns chunks no bigger than 'chunk_size + chunk_overlap'" do
        parser = Parsers::Text.new(document)
        chunks = subject.chunk(parser.text)
        expect(chunks.first.content.size).to be <= chunk_size + chunk_overlap
        expect(chunks.last.content.size).to be <= chunk_size + chunk_overlap
      end
    end

    # context "without overlap" do
    #   let(:chunk_overlap) { 0 }

    #   parser = Parsers::Text.new(:document)
    #   chunks = subject.chunk(parser)

    #   it "returns chunks no bigger than 'chunk_size'" do
    #     expect(chunks.first.content.size).to be <= chunk_size
    #     expect(chunks.last.content.size).to be <= chunk_size
    #   end
    # end
  end
end
