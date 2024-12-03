module Converters
  #
  # A converter takes a `Document` to convert into a new `Document` with contents
  # in a different format. The new document should refer to the original
  # one as its parent.
  class Base
    attr_reader :input_document, :status

    def initialize(document)
      @input_document = document
      @status = Status::READY
    end

    # Perform the conversion and return the new `Document` on success.
    def convert
      error!
      raise UnimplementedConverter, "Base converter doesn't do anything"
    end

    # Override to check the document's content type / format
    # to determine if it can be converted. For e.g. a PDF converter
    # should check if the document's content type ends with '/pdf'.
    def self.can_convert?(_document)
      false
    end

    def ready?
      @status == Status::READY
    end

    def error!
      @status = Status::ERROR
    end

    def error?
      @status == Status::ERROR
    end

    def done!
      @status = Status::DONE
    end

    def done?
      @status == Status::DONE
    end

    protected

    # Creates a temporary file (using `#file_extension`) to save the content and returns a
    # new `Document`. Call this after conversion is done.
    def create_document(content, output_file_extension:, binmode: true)
      Tempfile.create(['conv-', output_file_extension], binmode:, encoding: content.encoding) do |tempfile|
        tempfile.write(content)
        tempfile.rewind
        create_child_document(filename: File.basename(tempfile.path), io: tempfile)
      end
    end

    def create_child_document(filename:, io:)
      new_doc = Document.new(
        filename:,
        parent: input_document,
        chunking_profile: input_document.chunking_profile,
        collection: input_document.collection,
        user: input_document.user)
      new_doc.file.attach(io:, filename:)
      new_doc.save
      new_doc
    end
  end
end
