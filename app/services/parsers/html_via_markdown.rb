# frozen_string_literal: true

module Parsers
  # HTML parser converts HTML documents into commonmark (with tables) markdown
  class HtmlViaMarkdown < CommonMark
    CMD = <<~TEXT
      pandoc -s -f html --strip-comments --to=markdown-raw_attribute - | grep -v "^:" |\
      grep -v '^```' |\
      grep -v '<!-- -->' |\
      sed -e ':again' -e N -e '$!b again' -e 's/{[^}]*}//g'
    TEXT

    ENDFRONTMATTER = "---\n\n"

    def initialize(document)
      super(document)
      # Convert the HTML into markdown, strip out all the junk we don't need
      rawtxt, serr, status = Open3.capture3(CMD, stdin_data: @document.contents, binmode: true)
      if status.success?
        # extract the front matter from the raw text
        @title = rawtxt.match(/title: (.+)\n/).captures.join
        # remove the front matter to get the body
        @text = rawtxt[(rawtxt.index("---\n\n") + 5)..]
      else
        Rails.logger.error("Error running '#{cmd}' on HTML: #{@document.filename}\n#{serr}")
        raise StandardError, "Error converting HTML to markdown: #{@document.filename}'"
      end
    end

    def title
      @title || super
    end
  end
end
