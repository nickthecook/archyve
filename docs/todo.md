# Todo

Work that is known, shaped, and deliberately not done yet. Decisions that shape
the system live in `architecture.md`; this is the queue.

## Surfacing sync failures to the user

**Problem.** A sync can fail in three quite different ways, and today only the
first is visible:

1. **The scan failed.** `Sources::Sync` records `status: "failed"` and the
   exception on the `SourceSync` row, and the source page shows it. This
   case is done.
2. **The scan succeeded, but individual items failed.** Counted in
   `failed_count` and shown as "errored", but *which* items and *why* is only in
   the Rails log. The user sees "3 errored" with no way to learn which three.
   (Note these are bookkeeping failures inside `reconcile` — the scan never reads
   a file. Read and extraction failures land on the *document*, and want the same
   treatment from a different angle.)
3. **The worker died mid-scan.** The run stays `running` forever. The source
   page flags it as stalled after an hour, but nothing recovers it and nothing
   explains it.

The user's question in each case is the same: *was this transient — do I just let
it sync again — or is it something I have to fix?* Answering that needs the error
text, per item, kept somewhere the UI can read.

**Shape of the work.**

- **Per-item failures need a home.** Options: a `source_sync_items` table (a
  row per failure: external_id, error class, message, occurred_at), or a jsonb
  `failures` column on `source_sync` capped at N entries. The table is the
  honest version and supports "this file has failed every scan for a week"; the
  column is cheaper and probably enough to start. Leaning to the column, with
  the table as the upgrade path if per-item history turns out to matter.
- **Classify transient vs permanent.** `Errno::ENOENT` on a file that was there a
  moment ago is transient; a Docling extraction failure on a corrupt PDF is
  permanent. Even a rough split ("network/IO" vs "content") changes what the UI
  should advise. Worth deriving from the exception class rather than asking the
  user to interpret a stack trace.
- **Stalled runs need a sweeper.** A periodic job that finds `running` runs older
  than a threshold whose jobs are no longer in flight, marks them `failed` with
  "worker did not report back", and leaves the source free to sync again.
  Solid Queue's own `Batch.sweep_stalled` is the model for the shape, though the
  bookkeeping here is ours. Promoted by "The web source", phase 1: once a scan
  can span several jobs, a stuck `running` row is the expected outcome of an
  unlucky restart rather than a rare one, and it blocks `Source.due_for_sync`
  permanently.
- **A place to look.** The source page shows the last run; failures across
  runs probably want their own view ("documents that aren't ingesting"), since
  the natural question is about a *document* over time, not a *run*.

**Related, already handled:** a document whose ingest failed is retried by the
next scan — `Sources::Sync#changed?` treats `failed` as changed. So the
failures above are visible-but-self-healing on the next interval, which is why
this is a todo and not a bug.

## The web source

Shaped 2026-09-20; nothing built. A site becomes an `Endpoints::Web`, a path
under it becomes a `Sources::Web`, and every HTML page reachable under that path
becomes a Document. Docling extracts and the existing pipeline does the rest, so
this is a new way of *finding* documents, not a new way of processing them.

Ordered so that everything not specific to crawling ships first. The sync engine
needs three changes that Folder and BookStack want anyway, and doing them
underneath a new crawler would mean debugging two unfamiliar things at once.

### Phase 1 — Resumable, budgeted scans

`Sources::Sync#scan` runs a source's whole enumeration in one `SyncJob`. That is
fine for a folder and a wiki and wrong for a crawl, which is hours of network I/O
and cannot be enumerated without fetching. Three specific failures, none of them
crawler-specific:

- **Thread starvation.** `config/queue.yml` gives one worker process three
  threads across all queues. A multi-hour scan holds one for the duration, and
  `ProcessDocumentJob` already blocks on Docling for up to 300s. Raise
  `JOB_CONCURRENCY` as the immediate fix; per-source or per-collection limits are
  the upgrade path if it ever matters.
- **The concurrency lock expires mid-scan.** `SyncJob` takes
  `limits_concurrency ... duration: 1.hour`. Solid Queue fixes `expires_at` when
  the semaphore is claimed and offers no public way to extend it, so there is no
  keepalive to write — a scan must simply finish inside the duration.
- **Nothing survives a restart.** `@seen` and `@counts` live in memory, so a
  deploy at hour three loses the run *and* leaves `SourceSync` stuck at
  `running`. `Source.due_for_sync` excludes sources with a running sync, so that
  row then blocks the source from ever syncing again with no timeout to clear it.

**The work.**

- **Add `documents.last_seen_sync_id`** and stamp it on every reconciled
  document, including the unchanged branch that `#redescribe` skips today.
  `tombstone_vanished` then becomes `where.not(last_seen_sync_id: run.id)` — a
  plain query instead of a `Set` in memory, and one a scan spanning several jobs
  can still answer. This is what makes resumption possible at all.

  It has to be a *second* column. Reusing `source_sync_id` looks free, since
  `Sync` is its only writer and nothing reads it, but `SourceSync#documents`
  hangs off it and both `#pipeline_statuses` and `#processing_finished?` read
  straight through that association. Stamping unchanged documents would pull
  every already-`processed` document into the run's pipeline meter — the same
  denominator inflation the tombstone exclusion in `#pipeline_statuses` exists to
  prevent. So `source_sync_id` keeps its meaning, "the run that created, updated
  or retired this document", and the new column carries "the run that last saw
  it".

- **Give a scan a wall-clock budget**, ~10–15 minutes. On expiry it saves its
  position and returns *without* finishing the run; the next scheduler tick
  resumes the same `SourceSync`. Folder and BookStack enumerate in seconds and
  will never reach the budget, so their behaviour is unchanged.

- **A fourth `SourceSync` status: `paused`.** Neither existing state can carry a
  scan that stopped on budget. `running` collides with
  `scope :stalled, -> { running.where(started_at: ...after.ago) }` — a crawl
  spanning four hours of ticks reports as stalled the whole time and the sweeper
  below eventually kills it. `failed` collides with `Sync#finish`, which stamps
  `source.last_synced_at` on every terminal status (deliberately: an unmounted
  folder should wait out its interval rather than retry every tick) — but
  `due_for_sync` gates on that column, so the crawl would idle a full interval
  instead of resuming on the next tick.

  So: `paused` is excluded from `stalled`, does not stamp `last_synced_at`, and
  gets a `due_for_sync` clause that resumes it next tick regardless of interval.
  This sharpens `running` too, which currently has to mean both things:
  **`running` = a job holds this now; `paused` = nothing holds it and it will be
  picked up.**

- **`source_syncs.last_progress_at`.** With the above, age alone no longer
  separates healthy from dead. A `paused` run with a fresh timestamp is resuming
  normally; a stale one is abandoned. It also lets a `running` run whose worker
  died be spotted without the hour of grace `stalled` currently allows, which is
  a better story for Folder and BookStack as well.

- **Sweep stalled runs.** Already on the list above under "Surfacing sync
  failures", item 3 — promote it. A permanently-`running` row stops being
  cosmetic once scans span jobs, and with `last_progress_at` the sweeper has
  something better than `started_at` to judge by.

- **Two comments go stale and must be rewritten**, not just left: `SourceSync`'s
  class comment says the scan's counts "are complete the moment `status` leaves
  `running`", which resumption breaks — they are complete at a *terminal* status.
  And `Sources::Sync`'s says the scan "runs to completion synchronously".

- **Watch the broadcast.** `after_commit :broadcast_to_source, on: [:create,
  :update]` fires on every save of the run, so saving progress frequently would
  push the source page's live region on every write. Keep progress saves coarse
  (once per pass), or narrow the callback to status transitions.

- **Subsumes** the "Large trees scan in one job" bullet at the foot of this file.

### Phase 2 — Contract groundwork

Also independent of crawling, also worth landing before it.

- **`Source.authoritative_scan?`, defaulting true.** Absence from a Folder or
  BookStack scan means the item is gone. Absence from a crawl means it was not
  *reached* — a rate limit, a timeout, a boundary rule that changed, a nav
  redesign that orphaned a subtree. `tombstone_vanished` must consult the
  contract rather than special-case a type, or the first bad crawl silently
  destroys the chunks for half an archive and the next one will not restore them
  until the content happens to change.
- **Formalise the `config` / `state` split.** `sources.state` is in the schema
  and no type has ever written it, so the boundary has never been tested and
  nothing enforces it: `store_accessor :state, …` reads identically to
  `store_accessor :config, …` at the call site. The rule is **`config` is what a
  person set and a form may submit; `state` is what the source learned and no
  form may touch** — enforced by keeping `state` out of the permitted keys, not
  by convention.
- **Response-code stats on `SourceSync`.** A jsonb histogram, not rows. See the
  decision below on why dead URLs do not become Documents.

### Phase 3 — Verify

Run the suite, then sync a real Folder source and a real BookStack source end to
end and confirm counts, tombstones and the source page are unchanged. Phases 1
and 2 touch the engine every existing source runs through; the crawler must not
be the thing that discovers they broke.

### Phase 4 — The crawler

In this order, because the first three steps are pure functions testable against
fixtures with no network at all:

1. **`Endpoints::Web`** — origin plus optional credentials (Basic, or a static
   bearer/header; cookie and form login are explicitly out of scope). `#access!`
   is a GET of the origin. `Http` needs redirect handling, which it has none of
   today: a 301 currently raises through `raise_error`. Handle 3xx in the crawler
   rather than adding `faraday-follow_redirects`, so each hop can be inspected.
2. **URL canonicalisation and the boundary rule.** Lowercase host, no trailing
   slash, no fragment, query strings stripped entirely. Same host only, no
   extra-host allowlist until one is actually needed. Prefix matching is
   **segment-aware** — `/docs` must not match `/docsearch` — and re-checked after
   *every* redirect hop, not only on the seed URL.
3. **Content extraction.** Arc90 Readability against `Nokogiri::HTML5` (the HTML5
   parser, not the HTML4 default: it handles real tag soup the way a browser
   does). Remove `script, style, nav, header, footer, aside, form, noscript,
   iframe` and anything whose id/class matches the negative regex; score `p`, `td`,
   `pre`, `div` by text volume; propagate to parent and grandparent; penalise by
   link density (`link_text_length / total_text_length`, ~1.0 for a nav block and
   ~0.05 for prose — the single ratio that does most of the work). Try `main`,
   `article`, `[role=main]` first, since every common doc generator emits one, and
   fall back to scoring. Per-source `content_selector` as the escape hatch.
   Preserve `h1`–`h6`: `Ingestion::Chunker` builds its heading path from
   structure. Add `gem "nokogiri"` explicitly — it is only a transitive
   dependency via loofah today.
4. **`Sources::Web`** — `sitemap.xml` when the site has one, crawl as the
   fallback. `#each_item` conditional-GETs with stored ETag/Last-Modified; a 304
   replays the cached link set without re-parsing. `#read` re-fetches and
   re-extracts. `authoritative_scan?` is false unless the frontier drained.
5. **Politeness** — robots.txt and crawl-delay honoured, per-page
   `meta[name=robots]` too, an identifying User-Agent, one or two connections per
   host. GET and HEAD only.
6. **UI** — the source form, and the crawl stats on the run.
7. **SPA detection.** A client-rendered page extracts to near-zero text.
   `Ingestion::NothingReadable` already has the right shape; the point is that it
   must report, not silently store an empty document.

### Decisions, so they don't get re-derived

**Endpoint is the origin; Source holds the path prefix.** Not one source per
endpoint, as first assumed — the prefix *is* a subset selector, and `/docs` and
`/support` feeding different collections is the same shape as one BookStack
endpoint with several shelf-scoped sources. Mechanically it also keeps a path out
of `Endpoint#base_url`, which means "host root" everywhere else and is handed
straight to Faraday, where a path base does surprising things to relative
resolution.

**The version token is a hash of the extracted content, never of the response
body.** Raw HTML churns on every request — CSRF tokens, render timestamps,
rotating sidebars — so a body hash marks every page changed on every crawl and
re-embeds the whole site hourly. This is why extraction happens in the source,
before versioning, rather than being left to Docling.

**Two hashes on a document, deliberately.** `source_version` is the extracted
content; `source_metadata["checksum"]` is the raw bytes, written by
`ImportItemJob`. Its `unchanged?` guard is therefore inert for this type: the
raw hash almost never matches, but `Sync#changed?` has already filtered on the
extracted hash, so it only runs for pages that genuinely moved. Harmless, and
*not* to be "fixed" by making the two consistent — that reintroduces the churn
above. Comment it at the point of divergence.

**Boilerplate is a retrieval problem, not just a tidiness one.** Nav, sidebar and
footer repeated across every page put a large identical span in every chunk of
every document — the same objection that keeps BookStack container descriptions
out of the embedding, and a plausible contributor to the "everything scores 0.6"
symptom under *Later*.

**Dead URLs do not become Documents.** Tempting, for the failure stats, but a URL
that *was* a document and now 404s must tombstone — turning it into an error
document marks it seen, suppresses the tombstone, and leaves stale chunks
searchable forever. A URL that was *never* a document is a fact about the crawl,
not about the archive, so response-code counts live on `SourceSync`. Note that
`Item#skip_reason` cannot serve here regardless: `Sync#reconcile` returns before
creating a document, and `count_uningestable` reads a skip as "the source has it,
we declined it" — the opposite claim to a 404.

**`each_item` becomes a writer.** Resumption means persisting frontier and budget
mid-scan, and no existing source mutates anything while enumerating. This is what
makes the `config` / `state` split load-bearing rather than merely tidy.

The write ordering is safe as it stands, and worth recording so nobody re-derives
it: `Sync#call` is sequential — every `each_item` write lands during `scan`, and
`#finish` runs afterwards — and `#finish` assigns only `last_synced_at`, so with
`partial_updates` on under `load_defaults 8.1` its UPDATE never carries `state`.
There is no collision between the two.

The standing hazard is generic, and applies to whatever writes `state` later:
`store_accessor` is a read-modify-write, reading the whole hash out of the
in-memory attribute, merging one key and writing it back. A stale instance
therefore reverts the *entire* hash rather than losing one key. Keep one instance
of the row per pass — `each_item` is an instance method, so `self` already is the
object `Sync` holds — and assign and `save!`. Not `update_column(:state, …)`,
which looks like the careful choice and is the worst of the options: it bypasses
dirty tracking and leaves the in-memory attribute stale for the rest of the pass.

**Per-URL bookkeeping lives on the Document, not in `state`.** ETag,
Last-Modified and the outbound link set go in `source_metadata`; `state` holds
only the frontier cursor, budget consumed and whether the last pass drained.
Putting the link graph in `state` would mean 30–80 links per page at ~60 bytes
each — 15–25MB of jsonb for a 5,000-page site, TOASTed and rewritten in full
several times per crawl.

**Query strings are stripped, with no per-source allowlist** until one proves
necessary. Cycles are trivial (a visited set); infinite *spaces* are what kill
crawlers — calendars, facets, sort parameters — and dropping the query string
closes most of them. Max pages and max depth are the backstop.

**A crawler with credentials is dangerous.** GET and HEAD only, `<a href>` only,
never a form: plenty of applications still put destructive actions behind a GET.
`rel="nofollow"` and robots.txt help and neither is a guarantee. The BookStack
note applies here too — whatever the credentials can reach is re-exposed under
Archyve's access model, not the site's.

**Later, not now:** headless rendering for SPAs; cookie/form authentication;
extra-host allowlists; per-source query-parameter allowlists; per-URL failure
history (the histogram first, rows only if it proves too coarse).

## Later

- **Retrieval discrimination is weak on short queries.** Observed 2026-09-07:
  "fireplace model" scored a kitchen-installation chunk at 61% against 65% for
  the actual fireplace manual. The usual cause is absent nomic task prefixes,
  and those are correctly applied (`Embeddings::Embed`), so it isn't that.
  Candidates, roughly in value order:
  - **Hybrid retrieval.** Dense embeddings alone miss exact tokens — model
    numbers, part codes — which is precisely what a query like this is made of.
    Postgres already has `tsvector`; fuse BM25 and dense ranks with RRF. Likely
    the largest single win, and no new infrastructure.
  - **Rerank the top ~50** with a cross-encoder. Directly targets the
    "everything scores 0.6" symptom, at the cost of a second model.
  - **Check what the breadcrumb prefix is doing.** `Ingestion::Chunker` prefixes
    each chunk with its heading path; on short chunks that generic
    manual/installation language may be a large share of the embedded text and
    is identical across unrelated manuals.
  - **Stop showing cosine as a percentage.** `(1 - distance) * 100` is a
    compressed, non-linear scale where 61 and 65 look adjacent and aren't.
    Rank, or a normalised score, would mislead less.

- **Document lookups that are still by bare id.** The document *selections* in
  `CollectionMembershipsController#create` and `UnsortedController#assign`, and
  the removal in `#destroy`, take ids without filtering by reachability. The
  destination collection is scoped, so this can only pull a document you can't
  otherwise see *into a collection you manage* — where you would then see it
  anyway. Worth closing with `Document.reachable_by` when convenient; not a
  privilege escalation.

## The BookStack source

Built 2026-09-18, model and UI both. The source form is now split per type the
way the endpoint forms are — `Source.form_component`, with the shared fields on
`Views::Sources::Form` — and the selector picker is drawn from a live call to
the wiki, so switching servers is a plain GET back to the same page (the form's
own "Browse" button, `formmethod: "get"`, no JavaScript). The endpoint is fixed
after creation: every document is keyed by a page id that means something else
on another server.

Still to do, in order:

- **Page tags.** Wanted (see below), and *not* on BookStack's page *list* — only
  on `/api/pages/{id}`. Capturing them therefore costs one detail fetch per page
  per scan, which is exactly the cost the cheap-scan rule refuses. The way out is
  to take them during `#read`, which already fetches that page, and have the
  import write them; that needs the item's metadata to be writable from the job,
  not only from the scan.
- **The shelf facet.** Same shape of problem: a shelf's books are only on the
  shelf's own record, so "which shelves is this book on" is one call per shelf in
  the wiki, not per selected shelf. Only worth paying once something reads it.
- **The source page names selections by count, not by name** — "1 book", not
  "Network design". The names live on the wiki, and drawing that page should not
  cost three API calls. The edit form lists them by name; it is already talking
  to the server.

Decisions, so they don't get re-derived:

**A page is a Document; nothing else is.** `external_id` is the page id, so a
page that moves between books is the same document rather than a delete plus a
create — the thing `Sources::Folder` can't do. Fetch
`/api/pages/{id}/export/markdown`, not HTML: one conversion between the author's
text and the chunk instead of two. Skip drafts and templates silently, the way
Folder passes over a `.DS_Store`. OCR off for this type — the markdown export
carries image *links*, so there is nothing in the document to OCR.

**Shelves, books and chapters do not become Documents.** Their descriptions are
aspirational ("this shelf contains…") and, worse, they are short and purely
topical — exactly the shape that wins a similarity contest against a topical
query, so they displace the runbook that actually answers. Container *names* are
reliable and get indexed as the path; container *descriptions* are stored in
`source_metadata` and shown in the UI, never embedded. Page tags are the sleeper:
short, controlled, usually accurate — capture them even before anything reads them.

**`documents` gains a `path` column.** Cross-source vocabulary, not a BookStack
field: Folder backfills it as `File.dirname(relative)` (nil at the top level,
where `dirname` answers `"."`). Stored without a leading slash, so Folder's
`2026/q1` and BookStack's `Handbook/Joining` read the same way. It composes with
`Chunk#structure["heading_path"]` into one breadcrumb from repository root to
paragraph. Record it only for now — whether `path` joins the embedded chunk text
is a separate, corpus-wide decision needing a re-embed.

**Path is `/Book/Chapter`, and shelves are not in it.** Shelves are
many-to-many with books, so a page has no single shelf path; picking one
arbitrarily churns whenever shelf membership changes. Shelves ride as a
multi-valued facet instead.

**The version token is the revision marker alone.** It is tempting to fold the
computed path into it so a move triggers a write, but the token is the wrong
lever: `Sources::Sync#reconcile` already writes `title` and `content_type` on the
changed branch, and the rule that generalises is *the source's description of an
item is written whenever it differs* — including on the **unchanged** branch.
Then renaming a book updates every page's path with zero fetches, where a
path-in-token scheme would fetch every page to discover the bytes were identical.
This needs `Source::Item` to carry `path` and `url`, and `Sync` to write them.
`url` is also what `docs/todo.md`'s stored-URL item has been waiting for:
BookStack is the first source that can return true from `user_accessible_links?`.

**Selection stores what was picked, not its expansion.** A flat list of
selectors — `[{shelf: 3}, {book: 12}, {chapter: 88}]` — resolved to a page set at
scan time, unioned and deduped by page id. "Sync this shelf" has to mean "and
whatever lands on it later". Deselecting needs no code: the pages fall out of the
scan and `tombstone_vanished` retires them, feed memberships retract, manual ones
survive. Keep the scan cheap the way Folder's is — books/chapters/shelves
wholesale for the tree, the paginated page list for `updated_at`, and no page
body fetched until `ImportItemJob` wants one.

**One source per shelf is the answer to shelf→collection mapping**, not
per-selector targeting. Sources feed collections wholesale today; N sources
against one wiki share one `Endpoint`, so the token is typed and rotated once.
Per-selector targeting would be a config key plus a change to
`ImportItemJob#feed_collections` — additive, so nothing here needs shaping for it.

**Pairing:** `Sources::Bookstack` must accept only an `Endpoints::Bookstack`.
Declare it once — `def self.endpoint_type = Endpoints::Bookstack` — and use it
for both the validation and scoping the endpoint picker's options.

**Access control consequence, decided deliberately:** the API token is issued to
one BookStack user and returns what that user may see. Anything inside a selected
book is ingested and then exposed under *Archyve's* model, not BookStack's.

**Later, not now:** page attachments and images as their own documents;
per-selector collection targeting; repointing a source between endpoints.

**Two things the build settled that the design hadn't.** The version token is
the page's `updated_at`, not `revision_count`: every BookStack resource carries
it, it moves on saves that mint no revision, and its over-reporting is caught by
`ImportItemJob`'s checksum for the price of one fetch — the same bargain Folder
strikes with mtime. And `external_id` is a page id, which carries no extension,
so the source names its own bytes: `Source#filename_for` defaults to
`File.basename(external_id)` and BookStack returns `<title>.md`, because Docling
picks its reader off the extension.

- **`Endpoint#accessed_at` is only written by the pre-flight.** `#access` exists
  so an admin can prove a new endpoint works before any source points at it, and
  today it is the only writer of `accessed_at` / `access_error`. Real use records
  nothing — `#client` is called by nothing but `#access!`. When the first source
  with an endpoint lands, record the outcome around the sync run (one write per
  run, not per HTTP request; a paginated wiki makes hundreds of calls).

- **Source credential encryption.** ~~Needed before the first source that holds
  credentials (S3 keys, a Bookstack token).~~ Done, by putting credentials
  somewhere else entirely: `Endpoint` holds the server and its secrets, and a
  source points at one. See `endpoints.credentials` (encrypted) beside
  `endpoints.config` (readable). Sources still hold no secrets.

  The warning below stands regardless, for whatever is tempted to put one there:

  **Do not encrypt `sources.config` wholesale.** `Source.due_for_sync` extracts
  `config->>'sync_interval_minutes'` *in SQL*, and the scheduler runs it every
  minute. Encrypting the column doesn't raise — the extraction just reads
  ciphertext and scheduling quietly goes wrong, while `store_accessor` keeps
  working in Ruby so it still looks fine. Add a separate encrypted column for
  secrets and leave `config` readable by SQL.

  **Keys come from the environment, not credentials.** The railtie splats
  `**app.config.active_record.encryption` *after* the credentials lookup, so
  setting these in `config/application.rb` overrides it:

      enc = config.active_record.encryption
      enc.primary_key         = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
      enc.deterministic_key   = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
      enc.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]

  Generate a set with `bin/rails db:encryption:init`, put them (and
  `SECRET_KEY_BASE`, which Rails reads from ENV natively and which is unrelated
  — nothing in AR encryption derives from it) in each environment's
  `secrets.ejson`. Each key raises only when read, so `primary_key` and
  `key_derivation_salt` are the two that matter; `deterministic_key` is needed
  only for `encrypts ..., deterministic: true`, i.e. columns you want to query
  by. Set all three anyway rather than discover the third later. Assigning nil *overrides* rather than falling back, so guard
  with `if ENV[...]` if the credentials fallback should survive. Nothing in this
  app reads credentials, so `master.key` need never reach a server.
- **Re-embedding the corpus.** The one piece `InferenceModel` points at and
  refuses without. Changing the embedding model strands every existing vector
  (different models, different vector spaces), so the model validates that no
  embedding from another model exists before allowing one — which means the
  embedder is effectively fixed for the life of an archive today. The job is:
  set the new model, re-embed every chunk, swap atomically. Note the schema
  constraint from architecture.md — `embeddings.embedding` is a `vector(768)`
  with one HNSW index, so a **different-dimension** model needs a new column or
  table, not just a new job. Same-dimension swaps are the easy first case.
  Until this exists, the UI says so in as many words rather than offering a
  control that quietly breaks search.
- **Nothing verifies a chat model before it is imported.** "Check" proves the
  server answers and discovery reports what it has, but an imported model is
  never actually prompted. A model that is pulled but broken looks fine until
  the first conversation.
- **Configurable file extensions per folder source.** Note the hazard: a file
  dropping out of the allowed list is not a file that left the source, so
  narrowing the list must go through the same `skip_reason` path that
  `max_file_size` uses, or it will tombstone documents.
- **Large trees scan in one job.** `Sources::Sync` walks the whole directory
  in a single `SyncJob`. Fine for thousands of files; a million would want
  chunked or resumable scanning. Superseded by "The web source", phase 1, which
  needs resumable scans for a different reason and fixes this on the way past.
- **Per-collection and per-source grants.** The global role is built; the
  second axis isn't. Needs `collection_users`, `source_users`, retrieval scoped
  to readable collections, and the feed picker moved to the collection page.
  (The "who may configure sources" question is settled: `operator`.)
