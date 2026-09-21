module Crawl
  # What belongs to a crawl and what doesn't, and the one canonical spelling of
  # every URL that does.
  #
  # Canonical form is what gives a page its identity — it is the document's
  # external_id and the frontier's dedup key — so the rules are deliberately
  # lossy. Query strings go entirely: a crawl that keeps them discovers a fresh
  # URL for every sort order and filter combination on a listing page and never
  # drains. Sites that put real content behind a query string exist, and this
  # will not read them; a crawler that never finishes reads nothing at all.
  #
  # The scheme is coerced to the origin's rather than compared against it. A
  # site that serves both http and https would otherwise hold two documents per
  # page, and the http→https redirect every such site does would be read as
  # leaving the boundary.
  #
  # There are two prefixes, because they answer to different people. `scope` is
  # the endpoint's, set by an admin, and binds everything — it is the limit on
  # what an operator may reach with that endpoint's credentials. `prefix` is the
  # source's, set by an operator, and says which part of that becomes documents.
  class Boundary
    SCHEMES = %w[http https].freeze

    attr_reader :origin, :scope, :prefix

    def initialize(origin:, scope: nil, prefix: nil)
      @origin = URI.parse(origin.to_s.strip)
      @scope = normalize_prefix(scope)
      @prefix = normalize_prefix(prefix)
    end

    # Where a crawl with nothing else to go on starts.
    def seed = "#{origin_root}#{prefix.presence || scope}"

    # A link, as this crawl would record it, or nil if it is not ours to follow.
    def resolve(href, base:)
      url = canonicalize(href, base: base)
      url if url && include?(url)
    end

    # Ours to keep. Both prefixes are checked rather than assuming the source's
    # nests inside the endpoint's: a validation says it must, and a scope
    # narrowed after the fact would otherwise leave the old sources crawling on.
    def include?(url) = within?(url, prefix) && within?(url, scope)

    # Ours to fetch at all, whether or not anything comes of it. A start page
    # sits outside the source's prefix by design, so it is this — not
    # `include?` — that stops it being a way to reach the rest of the host.
    def reachable?(url) = within?(url, scope)

    # Absolute, canonical, and in this crawl's scheme — whether or not it is
    # inside the boundary. Redirect targets are canonicalised before they are
    # judged, so the two halves are separate.
    def canonicalize(href, base: nil)
      uri = absolute(href, base)
      return unless uri && SCHEMES.include?(uri.scheme&.downcase)

      "#{origin.scheme}://#{host_and_port(uri)}#{normalize_path(uri.path)}"
    rescue URI::Error, ArgumentError
      nil
    end

    private

    def absolute(href, base)
      href = href.to_s.strip
      return if href.empty? || href.start_with?("#")

      uri = base ? URI.join(base, href) : URI.parse(href)
      uri.fragment = nil
      uri.query = nil
      uri
    end

    def origin_root = "#{origin.scheme}://#{host_and_port(origin)}"

    # A port that was implicit in the URL as written is dropped, so
    # https://site and https://site:443 are one document rather than two.
    # Judged against the *incoming* scheme's default, before the coercion
    # above: http://site:443 is a link whose port was stated for a reason.
    def host_and_port(uri)
      host = uri.host.to_s.downcase
      return host if uri.port.nil? || uri.port == uri.default_port

      "#{host}:#{uri.port}"
    end

    # No trailing slash anywhere, root included: /docs/ and /docs are one page,
    # and so are https://site/ and https://site.
    def normalize_path(path)
      path.to_s.sub(%r{/+\z}, "")
    end

    def normalize_prefix(value)
      path = value.to_s.strip
      return "" if path.empty? || path == "/"

      normalize_path(path.start_with?("/") ? path : "/#{path}")
    end

    def within?(url, path_prefix)
      uri = URI.parse(url)
      uri.host&.downcase == origin.host&.downcase && under?(uri.path, path_prefix)
    rescue URI::InvalidURIError
      false
    end

    # Segment-aware, so /docs takes /docs and /docs/guide but not /docsearch.
    def under?(path, path_prefix)
      return true if path_prefix.empty?

      path = normalize_path(path)
      path == path_prefix || path.start_with?("#{path_prefix}/")
    end
  end
end
