module Crawl
  # The crawl's position, kept in `source_sync_items` rather than in memory.
  #
  # A pending row is an unmet obligation and a resolved one is proof an attempt
  # happened and what came of it, so seeding a crawl is one insert and resuming
  # it after the wall-clock budget — or after a deploy — is a query. Dedup is
  # the table's unique index rather than a discipline: two links to the same
  # page insert twice and the second is absorbed, with no check-then-act in
  # between.
  class Frontier
    # A crawl that ends because it ran out of allowance has not seen the site,
    # so it may not tombstone. Both caps exist for the same reason: a frontier
    # has no natural bound. Stripping query strings narrows the space of URLs a
    # calendar or a faceted list can generate; it does not close it.
    DEFAULT_MAX_PAGES = 10_000
    DEFAULT_MAX_DEPTH = 20

    def initialize(run, max_pages: DEFAULT_MAX_PAGES, max_depth: DEFAULT_MAX_DEPTH)
      @run = run
      @max_pages = max_pages.to_i
      @max_depth = max_depth.to_i
    end

    attr_reader :run, :max_pages, :max_depth

    def seeded? = items.exists?
    def drained? = !items.pending.exists?
    def exhausted? = attempted >= max_pages

    def attempted = items.resolved.count

    # Whether a page this crawl never *saw* may be read as deleted.
    #
    # Narrower than it sounds, and deliberately blunt. A page nothing linked to
    # leaves no row at all, which is indistinguishable from a page hidden behind
    # a URL that failed — so the question cannot be asked per page, only of the
    # run: did anything fail in a way that could be concealing pages from me?
    #
    # One inconclusive row anywhere is enough to say yes, even a leaf that led
    # nowhere, because we never saw its links and so cannot prove it led
    # nowhere. A tolerance was tried and is wrong: the ratio is over URLs the
    # crawl *discovered*, and the pages at risk are exactly the ones missing
    # from that denominator, so a hub failing among five hundred good pages
    # sails under any threshold while hiding everything behind it.
    #
    # Over-conservative in one direction only. A deferred deletion costs a scan
    # interval and fixes itself on the next clean run; a wrong one costs every
    # chunk and embedding behind the page. Documents this holds back are counted
    # on the run so a source that has quietly stopped pruning says so.
    #
    # Draining also covers the page budget: a crawl stopped by its allowance
    # still has pending rows. Only answerable before `Sources::Sync` reaps, which
    # is the right way round — `tombstone_vanished` is its only caller.
    def authoritative?
      drained? && attempted.positive? && items.inconclusive.none?
    end

    # Add URLs the crawl has learned about. Anything already known — pending or
    # long since resolved — is absorbed by the unique index.
    def discover(urls, depth: 0)
      return 0 if depth > max_depth

      urls = Array(urls).uniq
      return 0 if urls.empty?

      now = Time.current
      rows = urls.map do |url|
        { source_sync_id: run.id, external_id: url, detail: { "depth" => depth },
          created_at: now, updated_at: now }
      end

      items.insert_all(rows, unique_by: [:source_sync_id, :external_id]).rows.size
    end

    # The next URLs to fetch, oldest first, so a crawl advances roughly
    # breadth-first without holding a queue of its own.
    def take(limit)
      items.pending.order(:id).limit(limit).to_a
    end

    def resolve(item, disposition:, status_code: nil, detail: {})
      item.update!(disposition: disposition, status_code: status_code,
        detail: item.detail.merge(detail.stringify_keys))
    end

    def depth_of(item) = item.detail["depth"].to_i

    private

    def items = run.items
  end
end
