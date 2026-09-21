module Crawl
  # Arc90's readability heuristic: find the element on a page that holds the
  # article, and throw the rest of the page away.
  #
  # This runs in the *source*, before versioning, because boilerplate is a
  # retrieval problem and not only a tidiness one. Nav, sidebar and footer
  # repeated across a site put the same large span in every chunk of every
  # document, which is the same objection that keeps BookStack container
  # descriptions out of the embedding. It is also what makes a content hash
  # usable as a version token at all — raw HTML churns on every request.
  #
  # Headings survive on purpose: Ingestion::Chunker builds each chunk's heading
  # path out of h1–h6, so stripping them to plain text would cost every chunk
  # its context.
  class Readability
    # Structural furniture. Gone before scoring, so nothing in them can win.
    FURNITURE = "script, style, nav, header, footer, aside, form, noscript, iframe, svg, " \
                "button, select, template, link, meta".freeze

    # Where a page's own markup tells you which part is the article. Every
    # common documentation generator emits one of these, and believing it is
    # both cheaper and better than scoring.
    LANDMARKS = ["main", "article", "[role=main]", "#content", "#main-content"].freeze

    # id/class substrings that say "this is furniture" and "this is the body".
    # Matched against both attributes together.
    NEGATIVE = /combx|comment|contact|foot|masthead|media|meta|promo|related|scroll|shoutbox|
                sidebar|sponsor|shopping|tags|tool|widget|nav|menu|breadcrumb|banner|social|
                share|cookie|popup|subscribe|skip|pagination|toc|search/xi
    POSITIVE = /article|body|content|entry|hentry|main|page|post|text|blog|story|doc|markdown|prose/xi

    # What gets scored, and the floor under which a block is too short to mean
    # anything.
    CANDIDATES = %w[p td pre div section li blockquote].freeze
    MINIMUM_BLOCK = 25

    # A block whose text is mostly link text is a menu wearing a paragraph's
    # tag. This single ratio does most of the work the whole heuristic does:
    # roughly 1.0 for a nav block, roughly 0.05 for prose.
    LINK_DENSITY_LIMIT = 0.5

    # Tags kept in the output. Everything else is unwrapped to its contents, so
    # the text survives and the markup does not.
    KEPT = %w[
      h1 h2 h3 h4 h5 h6 p br hr ul ol li dl dt dd blockquote pre code
      table thead tbody tr th td em strong b i a figure figcaption
    ].freeze

    def self.call(...) = new(...).call

    # `selector` is the per-source escape hatch: a site whose markup defeats the
    # heuristic can name its content element outright.
    def initialize(document, selector: nil)
      @document = document
      @selector = selector.presence
    end

    def call
      strip_furniture
      node = chosen_node
      return unless node

      clean(node)
      node
    end

    private

    attr_reader :document, :selector

    def strip_furniture
      document.css(FURNITURE).each(&:remove)
      document.css("[hidden], [aria-hidden=true]").each(&:remove)
      document.xpath("//comment()").each(&:remove)

      document.css("div, section, span, ul, ol, aside").each do |node|
        node.remove if furniture?(node)
      end
    end

    def furniture?(node)
      signature = "#{node["id"]} #{node["class"]}"
      signature.match?(NEGATIVE) && !signature.match?(POSITIVE)
    end

    def chosen_node
      explicit = selector && first_matching(selector)
      return explicit if explicit

      LANDMARKS.each do |landmark|
        node = first_matching(landmark)
        return node if node && text_of(node).length >= MINIMUM_BLOCK
      end

      best_scoring_node
    end

    def first_matching(css)
      document.at_css(css)
    rescue Nokogiri::CSS::SyntaxError
      nil
    end

    # Score flows upward: a paragraph credits its parent in full and its
    # grandparent by half, so the element that holds *many* good paragraphs wins
    # over any single one of them.
    def best_scoring_node
      scores = Hash.new(0.0)

      document.css(*CANDIDATES).each do |node|
        text = text_of(node)
        next if text.length < MINIMUM_BLOCK

        score = 1 + text.count(",") + [text.length / 100, 3].min

        scores[node.parent] += score + weight(node.parent) if element?(node.parent)
        scores[node.parent.parent] += (score + weight(node.parent.parent)) / 2.0 if element?(node.parent&.parent)
      end

      scores.max_by { |node, score| score * (1 - link_density(node)) }&.first
    end

    def weight(node)
      signature = "#{node["id"]} #{node["class"]}"
      (signature.match?(POSITIVE) ? 25 : 0) + (signature.match?(NEGATIVE) ? -25 : 0)
    end

    # Inside the winner, drop the blocks that are still menus — a table of
    # contents sitting in the article, a "related posts" list.
    def clean(node)
      node.css("div, ul, ol, table, section").each do |child|
        next if child.css("p, pre, h1, h2, h3, h4, h5, h6").any?

        child.remove if text_of(child).length < MINIMUM_BLOCK || link_density(child) > LINK_DENSITY_LIMIT
      end

      node.css("*").each do |child|
        child.replace(child.children) unless KEPT.include?(child.name)
      end
    end

    def link_density(node)
      total = text_of(node).length
      return 0.0 if total.zero?

      node.css("a").sum { |link| text_of(link).length } / total.to_f
    end

    def element?(node) = node.is_a?(Nokogiri::XML::Element)
    def text_of(node) = node.text.gsub(/\s+/, " ").strip
  end
end
