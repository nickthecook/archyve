# frozen_string_literal: true

module Parsers
  # DOCX parser converts word documents into commonmark (with tables) markdown
  class Docx < CommonMark
    CMD = 'pandoc -f docx  --wrap=none --to=commonmark -'

    def initialize(document)
      super(document)
      # NOTE: Using -raw opt causes text to be broken up a lot; but not using raw
      #       may cause tables to be "pretty" in text which may not be ideal for chunking.
      #       Not specifying works best for rotated pages, so doing that for now
      @text, e, s = Open3.capture3(CMD, stdin_data: @document.contents, binmode: true)
      raise_error(e) unless s.success?
    end

    def self.can_parse?(filename, content_type)
      content_type&.include?("officedocument.word") || filename.end_with?(".docx")
    end

    private

    def raise_error(error_output)
      error = error_output&.lines&.first || 'Unknown error running pandoc'
      Rails.logger.error("Error running '#{CMD}' on DOCX: #{filename}\n#{error}")
      raise StandardError, "Error converting DOCX to markdown: #{filename}: #{error}"
    end
  end
end
