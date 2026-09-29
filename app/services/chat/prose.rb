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
  # The markdown pass and its allowlist sanitizer belong to Markdown, shared
  # with document text because both arrive from somewhere that isn't us. What
  # is left here is the citation pass, which only model output ever gets.
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

    def self.call(content, hits: {}) = new(content, hits:).call

    def initialize(content, hits: {})
      @content = content.to_s
      @hits = hits
    end

    def call
      fragment = Markdown.fragment(@content)
      fragment.xpath(".//text()").each { cite(it) }
      fragment.to_html
    end

    private

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
      tag["href"] = hit.href if hit.followable?
      tag["title"] = [hit.title, hit.heading_path.presence].compact.join(" › ")
      tag["class"] = CITATION_CLASS
      tag.content = handle.to_s
      tag.to_html
    end

    def escape(text) = CGI.escapeHTML(text)
  end
end
