# frozen_string_literal: true

module Chat
  # What the model wrote, as HTML: markdown rendered, citation markers turned
  # into links to the documents they name.
  #
  # ## Markdown first, citations second
  #
  # The two passes can't be swapped. Citations rendered first would be HTML that
  # the markdown pass escapes back into visible angle brackets; run second, over
  # the *text nodes* of the rendered tree, they also stay out of fenced code —
  # a model quoting `results[1]` in a code sample is showing an array index, not
  # citing anything.
  #
  # ## Nothing the model writes is trusted with the page
  #
  # Rendered with `unsafe: false`, so raw HTML in a completion is escaped rather
  # than executed. A model that emits `<script>` has written a string, and the
  # transcript shows it as one.
  class Prose
    # Every bracket a model reaches for, not only the one it was asked to use.
    #
    # The instructions say to write [1], and models write what they like:
    # gpt-oss emits the CJK 【1】, others the fullwidth ［1］, and several group
    # their sources as [1, 2]. A citation that doesn't match is a citation that
    # doesn't link, which is the whole feature gone — and no amount of prompting
    # makes a local model consistent about punctuation. Cheaper to read all.
    OPEN = "\\[\\u3010\\uFF3B".freeze
    CLOSE = "\\]\\u3011\\uFF3D".freeze
    SEPARATOR = /\s*[,;]\s*/
    MARKER = /[#{OPEN}]\s*(\d{1,2}(?:#{SEPARATOR.source}\d{1,2})*)\s*[#{CLOSE}]/

    # Where a citation must not be rewritten: code is quoted, not written, and
    # an anchor inside an anchor isn't a thing.
    LITERAL = %w[code pre a].freeze

    CITATION_CLASS = "mx-0.5 rounded-sm border border-accent/60 bg-accent/10 px-1 align-super " \
                     "font-mono text-[0.7rem] text-accent tabular-nums hover:bg-accent/20 transition-colors"

    # GFM, because that is the dialect models emit. Hard breaks because a model
    # writing a list of lines means them as lines — commonmark's "a single
    # newline is a space" rule turns a stanza of steps into one paragraph.
    #
    # `unsafe: true` renders the HTML a model writes instead of replacing it
    # with a comment — models put <br> inside table cells, and dropping it runs
    # three bullet points into one line. Nothing reaches the page on that
    # promise alone: the result goes through the sanitizer below, which is a
    # vetted allowlist rather than a parser flag.
    RENDER = { unsafe: true, hardbreaks: true }.freeze
    #
    # `header_ids: nil` because a heading in a chat answer is a heading, not a
    # linkable section — the anchor commonmarker adds by default is a link to
    # nowhere useful inside a transcript.
    EXTENSIONS = {
      table: true, strikethrough: true, autolink: true, tasklist: true, header_ids: nil
    }.freeze

    # Highlighting is off: its colours arrive as inline styles, which the
    # sanitizer strips — leaving a fenced block full of empty spans that render
    # exactly like plain code and complicate every pass over the tree.
    PLUGINS = { syntax_highlighter: nil }.freeze

    # The sanitizer's own safe list, plus the table tags GFM produces and Rails
    # doesn't list, minus images: an answer has no business fetching a remote
    # resource, and a document carrying an injected `<img src=…>` would make the
    # page call it for them.
    TAGS = (Rails::HTML5::SafeListSanitizer.allowed_tags - ["img"] +
            %w[table thead tbody tfoot tr td th colgroup col]).freeze
    ATTRIBUTES = (Rails::HTML5::SafeListSanitizer.allowed_attributes - ["src"] + ["align"]).freeze

    def self.call(content, hits: {}) = new(content, hits:).call

    def initialize(content, hits: {})
      @content = content.to_s
      @hits = hits
    end

    def call
      fragment = Nokogiri::HTML5.fragment(sanitized)
      fragment.xpath(".//text()").each { cite(it) }
      fragment.css("a[href]").each { leash(it) }
      fragment.to_html
    end

    private

    # Sanitized before citations are woven in, so the anchors this adds are the
    # only markup on the page that wasn't checked by somebody else.
    def sanitized
      Rails::HTML5::SafeListSanitizer.new.sanitize(markdown, tags: TAGS, attributes: ATTRIBUTES)
    end

    def markdown
      Commonmarker.to_html(@content, options: { render: RENDER, extension: EXTENSIONS }, plugins: PLUGINS)
    end

    def cite(node)
      return if node.ancestors.any? { LITERAL.include?(it.name) }
      return unless node.content.match?(MARKER)

      node.replace(node.content.split(MARKER).each_with_index.map do |part, index|
        # split with a capture group alternates literal text and captured handles
        index.odd? ? citations(part) : escape(part)
      end.join)
    end

    # One bracket may hold several handles. Each is resolved on its own, so a
    # group like [1, 7] where only 1 was retrieved keeps the good citation
    # instead of discarding both.
    def citations(group)
      group.split(SEPARATOR).map { citation(it.to_i) }.join
    end

    # **A handle that doesn't match a hit is left as plain text**, not rendered
    # as a broken link — the model can invent "[7]" when only six results came
    # back, and the honest rendering of an invented citation is to show it as
    # the literal thing it is rather than dress it up as a source.
    def citation(handle)
      hit = @hits[handle]
      return escape("[#{handle}]") if hit.nil?

      tag = Nokogiri::XML::Node.new("a", Nokogiri::HTML5::Document.new)
      tag["href"] = "/documents/#{hit.document_id}" if hit.followable?
      tag["title"] = [hit.title, hit.heading_path.presence].compact.join(" › ")
      tag["class"] = CITATION_CLASS
      tag.content = handle.to_s
      tag.to_html
    end

    # A link the model wrote is a link to somewhere we know nothing about. Only
    # ones that leave the app: a fragment or a relative path is ours.
    def leash(node)
      return unless node["href"].to_s.match?(%r{\Ahttps?://}i)

      node["rel"] = "nofollow noopener"
      node["target"] = "_blank"
    end

    def escape(text) = CGI.escapeHTML(text)
  end
end
