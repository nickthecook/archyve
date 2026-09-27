require "digest"

module Sources
  # Pages under a path on a website, found by crawling it.
  #
  # The endpoint is the origin and this holds the path prefix, so one site can
  # feed several sources — /docs and /support into different collections — the
  # same shape one BookStack endpoint has with several shelf-scoped sources.
  #
  # Where a crawl *starts* is a separate question from what is in scope, and
  # `start_path` answers it. A wiki category page, a changelog, a hand-written
  # index — each links to content living elsewhere on the site, so pointing a
  # crawl at one and bounding it by that same path finds exactly one page.
  #
  # What makes this type different from every other is that enumerating and
  # fetching are the same act: the next page is only discovered by reading the
  # last one. So the scan is resumable, its position is rows in
  # `source_sync_items` rather than a cursor, and absence from a pass means
  # "not reached" until the frontier has drained cleanly. See docs/todo.md,
  # "The web source".
  class Web < Source
    CONTENT_TYPE = "text/html".freeze

    # How long a cached robots.txt stands before it is re-fetched.
    ROBOTS_TTL = 24.hours

    FETCH_TIMEOUT = 20

    # How many pending rows are read per trip to the database. Large enough
    # that the query is not per-page, small enough that a pass which is broken
    # out of has not read much it will never use.
    BATCH = 50

    # Raised when re-reading a page that was fine at scan time no longer works.
    UnreadableError = Class.new(StandardError)

    # Raised when the configured start page sits outside what the endpoint
    # reaches. A validation refuses that, so this catches the case a validation
    # can't: an admin narrowing the endpoint under a source that already exists.
    OutOfScopeError = Class.new(StandardError)

    store_accessor :config, :path_prefix, :start_path, :content_selector, :max_pages, :max_depth,
      :crawl_delay_seconds

    # Facts about the site that outlive any one pass — which is what `state` is
    # for. Nothing run-scoped lives here: a swept run would leave it behind,
    # still describing a run that no longer exists.
    store_accessor :state, :robots_txt, :robots_fetched_at

    validates :max_pages, numericality: { only_integer: true, greater_than: 0 }, allow_blank: true
    validates :max_depth, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_blank: true
    validates :crawl_delay_seconds, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
    validate :path_prefix_must_be_a_path, if: -> { path_prefix.present? }
    validate :start_path_must_be_a_path, if: -> { start_path.present? }
    validate :paths_must_be_within_the_endpoint, if: -> { endpoint.is_a?(Endpoints::Web) }

    def self.endpoint_type = Endpoints::Web
    def self.supports_sync? = true
    def self.resumable_scan? = true
    def self.user_creatable? = true
    def self.type_label = "Website"
    def self.form_component = Views::Sources::Forms::Web

    def location = [endpoint&.host, path_prefix.presence].compact.join

    # What is stored is extracted HTML — the images were links in the original
    # and are not even that by the time Readability has been through it.
    def self.supports_ocr? = false

    def self.user_accessible_links? = true

    def self.description
      "Pages under a path on a website, found by crawling it. Read, never written."
    end

    def boundary
      @boundary ||= Crawl::Boundary.new(
        origin: endpoint.base_url, scope: endpoint.path_prefix, prefix: path_prefix
      )
    end

    # Absence means deleted only once the frontier has drained and the pages
    # that answered outnumber the ones that didn't. A crawl cut short by its
    # page budget says no even though it drained nothing.
    def authoritative_scan?(run) = frontier(run).authoritative?

    # Yields an Item per readable page under the prefix, crawling as it goes.
    #
    # The run is the crawl's position: its pending item rows are the frontier,
    # so a pass broken out of on Sources::Sync's budget resumes from the
    # database rather than from the seed. Nothing is held in memory that a
    # restart would lose.
    def each_item(run)
      return enum_for(:each_item, run) unless block_given?

      crawl = frontier(run)
      seed(crawl) unless crawl.seeded?

      until crawl.drained? || crawl.exhausted?
        batch = crawl.take(BATCH)
        break if batch.empty?

        batch.each do |item|
          # Per page rather than per batch: a batch is fifty URLs, and a cap
          # only honoured between batches would overshoot by up to forty-nine.
          # One indexed count against one HTTP fetch is not a cost worth saving.
          break if crawl.exhausted?

          visit(item, crawl) { |found| yield found }
        end
      end
    end

    # Re-fetch and re-extract. Deliberately not cached from the scan: the scan
    # ran on a different worker, possibly on a different day, and the bytes that
    # get attached should be the ones the page has now.
    def read(external_id)
      response = fetcher.get(external_id, follow: Crawl::Fetcher::MAX_REDIRECTS)

      unless response.ok?
        raise UnreadableError, "#{external_id} answered #{response.status || response.disposition}"
      end

      page = parse(response)
      raise Ingestion::NothingReadable, "#{external_id} extracted to nothing" unless page.readable?

      page.to_html
    end

    def document_url(document) = document.url

    # external_id is a URL, and Docling picks its reader off a file extension.
    def filename_for(document)
      "#{document.title.to_s.parameterize.presence || "page"}.html"
    end

    def max_pages = (super.presence || Crawl::Frontier::DEFAULT_MAX_PAGES).to_i
    def max_depth = (super.presence || Crawl::Frontier::DEFAULT_MAX_DEPTH).to_i

    # Whichever is slower: what the site asked for, or what the operator set.
    def crawl_delay
      [robots.crawl_delay.to_f, crawl_delay_seconds.to_f].max
    end

    def robots
      @robots ||= Crawl::Robots.parse(cached_robots_txt, agent: Endpoints::Web::USER_AGENT)
    end

    private

    def frontier(run)
      @frontier ||= {}
      @frontier[run.id] ||= Crawl::Frontier.new(run, max_pages: max_pages, max_depth: max_depth)
    end

    # Where the crawl begins, which is not the same question as what is in
    # scope. A wiki category, a changelog, a "docs index" — all of them link to
    # content that lives elsewhere on the site, so a source that has to start
    # at one says so and bounds itself with the path and the depth instead.
    #
    # An explicit start also turns the sitemap *off*. Naming a page to begin at
    # is asking for what that page reaches; seeding the whole site alongside it
    # would answer a question nobody asked.
    def seed(crawl)
      return crawl.discover([start_url], depth: 0) if start_path.present?

      # Otherwise the sitemap if the site publishes one, the prefix itself if
      # not. A sitemap is worth the one request: it reaches pages nothing links
      # to, and it starts a large site off breadth-first rather than down one
      # arm of the navigation.
      urls = sitemap_urls.select { |url| boundary.include?(url) }
      urls = [boundary.seed] if urls.empty?

      crawl.discover(urls, depth: 0)
    end

    # Checked against the endpoint's path rather than the source's: a start page
    # is *meant* to sit outside what the source keeps, which is exactly why it
    # would otherwise be a way to reach the whole host on the endpoint's
    # credentials.
    def start_url
      url = boundary.canonicalize(start_path, base: endpoint.base_url)
      return boundary.seed if url.blank?

      unless boundary.reachable?(url)
        raise OutOfScopeError, "#{start_path} is outside what #{endpoint.name} reaches"
      end

      url
    end

    # Fetch, extract, hand over, *then* resolve the row. The order is the whole
    # safety property and is the reverse of what a resumable source usually
    # wants — see docs/todo.md. Resolving first and dying before the yield would
    # leave the row saying the page was handled, the document unstamped, and the
    # frontier drained: `tombstone_vanished` would then destroy a document whose
    # page is fine. Yielding first costs, at worst, one page fetched twice.
    def visit(item, crawl)
      url = item.external_id
      depth = crawl.depth_of(item)

      return crawl.resolve(item, disposition: :robots_excluded) unless allowed?(url)

      response = fetch_page(url)
      return resolve_failure(item, crawl, response, depth) unless response.ok?

      page = parse(response)
      crawl.discover(links(page), depth: depth + 1) unless page.nofollow?

      # A starting page is fetched for what it links to even when it sits
      # outside the path — that is the whole point of naming one — but it is
      # not itself something the archive was asked for. Every other row got
      # here through the boundary already, so this only ever catches the seed.
      unless boundary.include?(url)
        return crawl.resolve(item, disposition: :out_of_scope, status_code: response.status)
      end

      if page.noindex? || !page.readable?
        return crawl.resolve(item, disposition: :nothing_readable, status_code: response.status,
          detail: { "reason" => page.noindex? ? "noindex" : "no text extracted" })
      end

      yield item_for(url, page)
      crawl.resolve(item, disposition: :ok, status_code: response.status)
    end

    # A site that canonicalises to a trailing slash answers our slash-less
    # canonical URL with a redirect straight back to the same page. Treated as
    # an ordinary redirect it would dead-end the crawl: the target canonicalises
    # back to this very row, which is already resolved, so nothing new is ever
    # discovered. Following it in place keeps one identity per page, and means
    # relative links resolve against the URL the server actually served — which
    # for a directory is a different answer.
    def fetch_page(url)
      response = fetcher.get(url)
      return response unless response.redirect? && response.location
      return response unless boundary.canonicalize(response.location, base: url) == url

      fetcher.get(response.location, follow: Crawl::Fetcher::MAX_REDIRECTS - 1)
    end

    # A redirect resolves this row and discovers its target as another — one URL
    # fetched once, one row each, and the boundary re-checked on the hop rather
    # than only on the seed.
    def resolve_failure(item, crawl, response, depth)
      if response.redirect?
        target = boundary.resolve(response.location, base: item.external_id)
        crawl.discover([target].compact, depth: depth)
      end

      crawl.resolve(item, disposition: response.disposition, status_code: response.status,
        detail: error_detail(response))
    end

    def error_detail(response)
      return {} unless response.error

      { "error" => response.error.class.name, "message" => response.error.message.to_s.truncate(500) }
    end

    # Resolved against the page's own base — a <base href> if it declares one,
    # and the URL the server served otherwise, which is not always the URL we
    # asked for.
    def links(page)
      page.hrefs.filter_map { |href| boundary.resolve(href, base: page.link_base) }.uniq
    end

    def item_for(url, page)
      html = page.to_html

      Item.new(
        external_id: url,
        version: Digest::SHA256.hexdigest(html),
        title: page.title.presence || url,
        content_type: CONTENT_TYPE,
        byte_size: html.bytesize,
        path: breadcrumb(url),
        url: url
      )
    end

    # Where the page sits under the prefix, as a breadcrumb: the URL's
    # directory, with the prefix and the page itself taken off.
    def breadcrumb(url)
      path = URI.parse(url).path.to_s.delete_prefix(boundary.prefix)
      segments = path.split("/").reject(&:empty?)

      segments[0..-2].join("/").presence
    rescue URI::InvalidURIError
      nil
    end

    def allowed?(url)
      robots.allowed?(URI.parse(url).path.presence || "/")
    rescue URI::InvalidURIError
      false
    end

    def parse(response)
      Crawl::Page.parse(response.body, url: response.url, content_selector: content_selector)
    end

    def fetcher
      @fetcher ||= Crawl::Fetcher.new(client: client, delay: crawl_delay)
    end

    def client
      endpoint.client(timeout: FETCH_TIMEOUT, raise_errors: false)
    end

    # Kept in `state` and re-read daily. It is a fact about the site rather than
    # about a run, which is exactly the line `state` draws.
    def cached_robots_txt
      fetched_at = robots_fetched_at && Time.zone.parse(robots_fetched_at.to_s)
      return robots_txt.to_s if fetched_at && fetched_at > ROBOTS_TTL.ago

      body = fetch_robots_txt
      update!(robots_txt: body, robots_fetched_at: Time.current.iso8601)
      body
    end

    def fetch_robots_txt
      response = Crawl::Fetcher.new(client: client).get("/robots.txt", follow: Crawl::Fetcher::MAX_REDIRECTS)
      response.status == 200 ? response.body.to_s : ""
    end

    # robots.txt names sitemaps; /sitemap.xml is the convention when it doesn't.
    def sitemap_urls
      locations = robots.sitemaps.presence || ["#{boundary.canonicalize("/", base: endpoint.base_url)}/sitemap.xml"]

      locations.flat_map { |location| Crawl::Sitemap.urls(location, fetcher: fetcher, boundary: boundary) }.uniq
    end

    # The endpoint's path is an admin's limit on what an operator may reach with
    # its credentials, so both of the source's paths have to sit inside it —
    # `start_path` included, for the reason given on #start_url.
    def paths_must_be_within_the_endpoint
      return if endpoint.path_prefix.blank?

      limit = Crawl::Boundary.new(origin: endpoint.base_url, scope: endpoint.path_prefix)

      { path_prefix: path_prefix, start_path: start_path }.each do |attribute, value|
        next if value.blank?
        next if limit.reachable?(limit.canonicalize(value, base: endpoint.base_url).to_s)

        errors.add(attribute, "must be under #{endpoint.path_prefix}, which #{endpoint.name} is limited to")
      end
    end

    def path_prefix_must_be_a_path = validate_path(:path_prefix, path_prefix)
    def start_path_must_be_a_path = validate_path(:start_path, start_path)

    def validate_path(attribute, value)
      return if value.to_s.start_with?("/") && !value.to_s.include?("://")

      errors.add(attribute, "must be a path beginning with /, not a full address")
    end
  end
end
