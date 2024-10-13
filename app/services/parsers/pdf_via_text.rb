module Parsers
  class PdfViaText < Text
    def initialize(document)
      super(document)
      # NOTE: Using -raw opt causes text to be broken up a lot; but not using raw
      #       may cause tables to be "pretty" in text which may not be ideal for chunking.
      #       Not specifying works best for rotated pages, so doing that for now
      cmd = 'pdftotext - -'
      @text, stderr, status = Open3.capture3(cmd, stdin_data: @document.contents, binmode: true)
      return if status.success?

      Rails.logger.error("Error running '#{cmd}' on PDF: #{@document.filename}\n#{stderr}")
      raise StandardError, "Error converting PDF to text: #{@document.filename}'"
    end
  end
end
