module Converters
  class PdfToText < Base
    def convert
      # NOTE: Using -raw opt causes text to be broken up a lot; but not using raw
      #       may cause tables to be "pretty" in text which may not be ideal for chunking.
      #       Not specifying works best for rotated pages, so doing that for now
      cmd = 'pdftotext - -'
      text, e, s = Open3.capture3(cmd, stdin_data: input_document.contents, binmode: true)
      if s.success?
        new_doc = create_document(text, output_file_extension: '.txt', binmode: false)
        done!
        return new_doc
      end

      error!
      Rails.logger.error("Error running '#{cmd}' converting PDF: #{input_document.filename}\n#{e}")
      raise ConversionError, "Error converting PDF to text: #{@document.filename}"
    end

    def self.can_convert?(document)
      document.content_type&.end_with?("/pdf")
    end
  end
end
