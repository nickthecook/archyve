module Parsers
  class Pdf
    include BasicTextChunker

    def initialize(document)
      @document = document
    end

    def text
      # NOTE: Using -raw opt causes text to be broken up a lot; but not using raw
      #       may cause tables to be "pretty" in text which may not be ideal for chunking.
      #       Not specifying works best for rotated pages, so doing that for now
      cmd = 'pdftotext - -'
      txt, = Open3.capture2(cmd, stdin_data: @document.contents, binmode: true)
      txt
    end
  end
end
