module Parsers
  # DOCX parser converts word documents into commonmark (with tables) markdown
  class Docx < CommonMark
    def initialize(document)
      super(document)
      # NOTE: Using -raw opt causes text to be broken up a lot; but not using raw
      #       may cause tables to be "pretty" in text which may not be ideal for chunking.
      #       Not specifying works best for rotated pages, so doing that for now
      cmd = 'pandoc -f docx  --wrap=none --to=commonmark -'
      @text, serr, status = Open3.capture3(cmd, stdin_data: @document.contents, binmode: true)
      return if status.success?

      Rails.logger.error("Error running '#{cmd}' on DOCX: #{@document.filename}\n#{serr}")

      raise StandardError, "Error converting DOCX to markdown: #{@document.filename}'"
    end
  end
end
