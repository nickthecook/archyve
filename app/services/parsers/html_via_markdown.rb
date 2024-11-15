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
      r, e, s = Open3.capture3(CMD, stdin_data: @document.contents, binmode: true)
      raise_error(e) unless s.success?

      # extract the title from front matter (pandoc -s for `markdown`)
      @title = r.match(/title: (.+)\n/).captures.join
      # remove the front matter to get the body
      @text = r[(r.index(ENDFRONTMATTER) + ENDFRONTMATTER.length)..]
    end

    def self.can_parse?(filename, content_type)
      content_type&.end_with?("/html") || filename.match?(/\.?html*\z/)
    end

    def title
      @title || super
    end

    private

    def raise_error(error_output)
      error = error_output&.lines&.first || 'Unknown error running pandoc'
      Rails.logger.error("Error running '#{CMD}' on HTML: #{@document.filename}\n#{error}")
      raise StandardError, "Error converting HTML to markdown: #{@document.filename}: #{error}"
    end
  end
end
