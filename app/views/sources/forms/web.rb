# frozen_string_literal: true

class Views::Sources::Forms::Web < Views::Sources::Form
  def self.new_heading = "Add a website"

  def self.new_blurb
    "Archyve crawls the site under the path you give it and keeps the archive matching what it finds."
  end

  def self.edit_blurb
    "Narrowing the path removes documents outside it from the archive on the next complete crawl."
  end

  private

  def new_server_hint
    "The site, and the sign-in Archyve crawls it with. Which part of it to take is the Path below."
  end

  def type_fields
    field("Path", "Which part of the site to crawl. Matched whole-segment, so /docs takes /docs/guide but not /docsearch.") do
      text_input(:path_prefix, @source.path_prefix, placeholder: "/docs", mono: true)
      what_gets_crawled
    end

    field("Start at", start_hint) do
      text_input(:start_path, @source.start_path, placeholder: "same as the path above", mono: true)
    end

    field("Content selector", content_selector_hint) do
      text_input(:content_selector, @source.content_selector, placeholder: "main.article", mono: true)
    end

    field("Limits", "A crawl stops at whichever it reaches first. A crawl that stops early never removes anything: it hasn't seen the site.") do
      limits_row
    end
  end

  # The two knobs answer different questions, and conflating them is how a
  # crawl of a wiki category finds exactly one page.
  def start_hint
    "Optional. Where to begin, when that isn't the path itself — a category page, a changelog, " \
      "a hand-written index. Its own links are followed, but it only becomes a document if it is " \
      "under the path. Naming one also stops the site's sitemap being used."
  end

  def what_gets_crawled
    note do
      p(class: "text-xs text-muted") { "Links are followed within this path only." }
      endpoint_limit
      p(class: "mt-1.5 text-xs text-faint") do
        plain "Query strings are dropped, so every page has one address. "
        plain "robots.txt and any crawl delay it asks for are honoured, and pages marked noindex are skipped."
      end
    end
  end

  # The endpoint may already be confined to part of the site, in which case this
  # path narrows *that* rather than the whole host. Shown only once a server has
  # been picked, since until then there is nothing to report.
  def endpoint_limit
    limit = @source.endpoint&.path_prefix
    return if limit.blank?

    p(class: "mt-1.5 text-xs text-amber-200/80") do
      plain "#{@source.endpoint.name} is limited to #{limit}, so this path must sit under it."
    end
  end

  def content_selector_hint
    "Optional. Archyve finds the article on each page by itself — nav, sidebar and footer are dropped so " \
      "they don't end up in every chunk. Name a CSS selector here if it gets it wrong on this site."
  end

  def limits_row
    div(class: "flex flex-wrap items-end gap-4") do
      number_field(:max_pages, "pages", @source.max_pages, Crawl::Frontier::DEFAULT_MAX_PAGES)
      number_field(:max_depth, "links deep", @source.max_depth, Crawl::Frontier::DEFAULT_MAX_DEPTH)
      number_field(:crawl_delay_seconds, "seconds between requests", @source.crawl_delay_seconds, 0, step: "0.1")
    end
  end

  def number_field(name, suffix, value, placeholder, step: "1")
    div(class: "flex items-center gap-2") do
      input(
        type: "number",
        name: "source[#{name}]",
        value: value,
        min: "0",
        step: step,
        placeholder: placeholder.to_s,
        class: "w-28 rounded border border-line bg-void/60 px-3 py-2 font-mono text-sm text-fg " \
               "placeholder:text-faint outline-none focus:border-accent transition-colors"
      )
      span(class: "text-sm text-muted") { suffix }
    end
  end
end
