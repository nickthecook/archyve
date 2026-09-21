require "zlib"

module Crawl
  # A site's own list of its pages. Worth the request even though every URL in
  # it still has to be fetched: it reaches pages nothing links to, and it seeds
  # a large site broadly instead of down one arm of the navigation.
  #
  # Nothing here is cached between runs. A run's item rows already are the
  # cached link set, and a resumed pass finds its frontier seeded and never
  # comes back here — so a conditional GET would have nothing left to save.
  module Sitemap
    # A sitemap index may point at sitemaps, which may point at sitemaps. Two
    # levels is the protocol's own limit and also as far as anyone sane goes.
    MAX_DEPTH = 2

    # A bound on how much of somebody else's XML we are willing to believe.
    MAX_URLS = 50_000

    def self.urls(location, fetcher:, boundary:, depth: 0)
      return [] if depth > MAX_DEPTH

      document = fetch(location, fetcher)
      return [] unless document

      nested = document.css("sitemapindex > sitemap > loc").map(&:text)
      return nested.flat_map { |nest| urls(nest.strip, fetcher: fetcher, boundary: boundary, depth: depth + 1) } if nested.any?

      document.css("urlset > url > loc")
        .filter_map { |loc| boundary.canonicalize(loc.text.strip) }
        .uniq
        .first(MAX_URLS)
    rescue StandardError => e
      Rails.logger.warn("sitemap #{location} unusable: #{e.class}: #{e.message}")
      []
    end

    def self.fetch(location, fetcher)
      response = fetcher.get(location, follow: Fetcher::MAX_REDIRECTS)
      return unless response.status == 200

      Nokogiri::XML(body_of(response))
    end

    # Large sitemaps are conventionally served gzipped, and by extension as
    # often as by content-type.
    def self.body_of(response)
      gzipped = response.content_type.to_s.include?("gzip") || response.url.to_s.end_with?(".gz")
      return response.body unless gzipped

      Zlib::GzipReader.new(StringIO.new(response.body)).read
    end
  end
end
