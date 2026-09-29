# frozen_string_literal: true

# GFM → sanitized HTML, for the markdown in this app that nobody wrote by hand:
# what a model streamed into a transcript, and what Docling reconstructed from a
# document.
#
# Citation markers are deliberately *not* handled here. Chat::Prose layers that
# pass on top, because it is only ever right for model output — a document that
# happens to contain "[1]" is quoting a footnote, not citing a search result.
module Markdown
  # Hard breaks because a model writing a list of lines means them as lines —
  # commonmark's "a single newline is a space" rule turns a stanza of steps into
  # one paragraph.
  #
  # `unsafe: true` renders the HTML a model writes instead of replacing it with a
  # comment — models put <br> inside table cells, and dropping it runs three
  # bullet points into one line. Nothing reaches the page on that promise alone:
  # the result goes through the sanitizer below, which is a vetted allowlist
  # rather than a parser flag.
  #
  # `escaped_char_spans: false` because comrak wraps every backslash-escaped
  # character in a span for round-tripping, and document text escaped on the
  # way in (see Docling::Result) would arrive here peppered with them.
  RENDER = { unsafe: true, hardbreaks: true, escaped_char_spans: false }.freeze

  # `header_ids: nil` because a heading here is a heading, not a linkable
  # section — the anchor commonmarker adds by default is a link to nowhere
  # useful inside a transcript or a chunk card.
  EXTENSIONS = {
    table: true, strikethrough: true, autolink: true, tasklist: true, header_ids: nil
  }.freeze

  # Highlighting is off: its colours arrive as inline styles, which the
  # sanitizer strips — leaving a fenced block full of empty spans that render
  # exactly like plain code and complicate every pass over the tree.
  PLUGINS = { syntax_highlighter: nil }.freeze

  # The sanitizer's own safe list, plus the table tags GFM produces and Rails
  # doesn't list, minus images: neither an answer nor a chunk has any business
  # fetching a remote resource, and text carrying an injected `<img src=…>`
  # would make the page call it for them.
  TAGS = (Rails::HTML5::SafeListSanitizer.allowed_tags - ["img"] +
          %w[table thead tbody tfoot tr td th colgroup col]).freeze
  ATTRIBUTES = (Rails::HTML5::SafeListSanitizer.allowed_attributes - ["src"] + ["align"]).freeze

  def self.to_html(text) = fragment(text).to_html

  # The parsed tree rather than a string, for a caller with another pass of its
  # own to make over it — see Chat::Prose, which would otherwise reparse.
  def self.fragment(text)
    Nokogiri::HTML5.fragment(sanitized(text)).tap do |doc|
      doc.css("a[href]").each { leash(it) }
    end
  end

  # Sanitized before anything else is woven in, so that markup added afterwards
  # is the only markup on the page that wasn't checked by somebody else.
  def self.sanitized(text)
    Rails::HTML5::SafeListSanitizer.new.sanitize(render(text), tags: TAGS, attributes: ATTRIBUTES)
  end

  def self.render(text)
    Commonmarker.to_html(text.to_s, options: { render: RENDER, extension: EXTENSIONS }, plugins: PLUGINS)
  end

  # A link we didn't write is a link to somewhere we know nothing about. Only
  # ones that leave the app: a fragment or a relative path is ours.
  def self.leash(node)
    return unless node["href"].to_s.match?(%r{\Ahttps?://}i)

    node["rel"] = "nofollow noopener"
    node["target"] = "_blank"
  end

  private_class_method :sanitized, :render, :leash
end
