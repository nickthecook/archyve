module Crawl
  # One fetched HTML page, read twice: once for where it leads, once for what it
  # says.
  #
  # Nokogiri::HTML5 rather than the HTML4 default — real sites are tag soup, and
  # the HTML5 parser recovers from it the way a browser does rather than
  # silently dropping the rest of the document at the first unclosed tag.
  class Page < Data.define(:title, :hrefs, :link_base, :robots, :content)
    # Below this much extracted text there is nothing worth indexing. A
    # client-rendered page is the case that matters: it parses fine, extracts to
    # near-nothing, and would otherwise be stored as an empty document that
    # nothing ever retrieves and nothing explains.
    MINIMUM_TEXT = 120

    def self.parse(html, url:, content_selector: nil)
      document = Nokogiri::HTML5(html.to_s)
      base = link_base_of(document, url)

      # Links and directives are read *before* extraction, which mutates the
      # document — navigation is exactly the furniture Readability throws away,
      # and it is also how the next page is found.
      new(
        title: title_of(document),
        hrefs: hrefs_of(document),
        link_base: base,
        robots: robots_of(document),
        content: absolutize(Readability.call(document, selector: content_selector), base)
      )
    end

    # A declared <base href> may itself be relative — "/" and "/docs/" are both
    # commonplace — and everything downstream joins against this, so it is
    # resolved here rather than at each use.
    def self.link_base_of(document, url)
      declared = document.at_css("base[href]")&.[]("href").presence
      return url.to_s if declared.nil?

      URI.join(url.to_s, declared.strip).to_s
    rescue URI::Error
      url.to_s
    end

    # Links are rewritten absolute before the extracted HTML becomes bytes: a
    # chunk is read far from the site it came from, where a relative href
    # resolves against Archyve and 404s.
    def self.absolutize(content, base)
      return content if content.nil? || base.to_s.empty?

      content.css("a[href]").each do |anchor|
        anchor["href"] = URI.join(base, anchor["href"].to_s.strip).to_s
      rescue URI::Error
        anchor.remove_attribute("href")
      end

      content
    end

    def self.title_of(document)
      [document.at_css("title"), document.at_css("h1")]
        .filter_map { |node| node&.text&.gsub(/\s+/, " ")&.strip.presence }
        .first
    end

    def self.hrefs_of(document)
      document.css("a[href]").filter_map { |anchor|
        anchor["href"] unless anchor["rel"].to_s.split(/\s+/).include?("nofollow")
      }.uniq
    end

    def self.robots_of(document)
      document.css("meta[name]").filter_map { |meta|
        meta["content"] if meta["name"].to_s.casecmp?("robots")
      }.join(",").downcase
    end

    def noindex? = robots.include?("noindex") || robots.include?("none")
    def nofollow? = robots.include?("nofollow") || robots.include?("none")

    def text = content&.text.to_s.gsub(/\s+/, " ").strip

    def readable? = text.length >= MINIMUM_TEXT

    # What gets stored and handed to Docling: the extracted article, headings
    # intact, wrapped in the minimum of a document. The title rides along in
    # <title> so a page whose heading changed is seen as changed — the version
    # token is a hash of exactly these bytes.
    def to_html
      <<~HTML
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"><title>#{CGI.escapeHTML(title.to_s)}</title></head>
        <body>#{content&.inner_html}</body></html>
      HTML
    end
  end
end
