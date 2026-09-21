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

- **Per-item failures need a home: `source_sync_items`.** Built 2026-09-20 — see the
  table under "The web source", phase 4, which this shares with the crawler's
  frontier. The alternative considered and dropped was a jsonb `failures` column
  on `source_sync` capped at N entries, which is cheaper and was the earlier
  lean. The bug below is what rules it out: once the failure list decides
  whether a document is tombstoned, it is correctness rather than diagnostics,
  and a cap means the overflow gets deleted. Silent data loss that only appears
  under load is the worst kind to design in.

- **Fixed 2026-09-20: a failed item was tombstoned.** `Sources::Sync#scan`
  rescues a per-item failure, counts it and moves on, and its comment claimed
  "the item goes unstamped, so it isn't tombstoned". The code did the opposite.
  All three `#reconcile` branches stamp `last_seen_sync` *inside* themselves, so
  a raise before the stamp left an existing document carrying the previous run's
  id, and `tombstone_vanished` matches `last_seen_sync_id IS DISTINCT FROM
  run.id` — true for exactly that document. Chunks destroyed and feed
  memberships retracted, on a pass that reported `completed`.

  Reachable whenever `document.update!` or `#redescribe` fails on a document
  that already exists: a validation failure, a deadlock, a constraint violation.
  Live for Folder and BookStack, with nothing to do with crawling.

  Fixed as the comment already claimed: each failure is recorded as an item row
  and those `external_id`s are excluded from `tombstone_vanished`. Per *run*, not
  per pass — tombstoning only happens on the pass that drains, which for a
  resumable source may be the fifth, and an in-memory list would be lost at every
  pause before it. Same principle as `authoritative_scan?`: absence is only
  evidence of deletion when the scan actually looked.

  One wrinkle worth keeping: an item with a blank `external_id` is counted but
  not recorded. There is no document it could correspond to, and writing the row
  anyway made `#record_failure` raise inside the rescue that exists to stop one
  bad item costing the scan — turning a skipped item into a failed run.
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

### Phase 1 — Resumable, budgeted scans — **built 2026-09-20**

`Sources::Sync#scan` ran a source's whole enumeration in one `SyncJob`. That was
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

- **The tally is written as the pass goes, not only at its end.** The counts
  reach the row on the same heartbeat, because the source page reads them from
  there: a pass running its whole budget would otherwise show zeros for fifteen
  minutes and then jump, which looks exactly like nothing happening. Paced at
  10s against the progress controller's 2.5s poll — this is a display concern,
  so it belongs near the poll rather than near the stall threshold. A run that
  dies now also keeps the tally it got through instead of reporting none.

  Note what does *not* need this: `pipeline_statuses` and the processing meter
  read the documents table directly, so they were always live during a scan.
  It is only the scan's own counters that lived in memory.

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

**A retired pass stands down.** The sweeper judges on `last_progress_at`, and
the one thing that timestamp cannot see is a pass wedged *inside* `#each_item` —
a hung fetch between yields reports no progress while its thread is alive and
well. Retired after an hour, it would wake to find the run failed, the source
due again, and `SyncJob`'s semaphore long expired: a second pass reconciling the
same source, racing its tombstones.

So `#record_progress` answers two questions in one statement. The heartbeat
write is conditional on the run still being `running`, so a retired run matches
nothing, reports zero rows changed, and the scan learns it is no longer the live
pass. It then breaks out and writes nothing further — no counts, no tombstones,
no `last_synced_at` — leaving the sweeper's verdict to stand. The `break` still
runs a resumable source's `ensure`, so the crawl position survives even though
the run's bookkeeping does not.

This is what the original sweeper item meant by runs "whose jobs are no longer
in flight", reached from the other end: rather than the sweeper proving a job is
dead, a live job proves itself alive and stands down when it can't.

**One thing the build settled that the design hadn't.** A pass stops with
`break`, which leaves `#each_item` immediately — so a resumable source has to
mark an item taken *before* yielding it, and persist its position from an
`ensure`. Get either wrong and the item that hit the budget is handed over again
on the next pass, double-counting itself in a run whose totals accumulate. This
is the whole reason `.resumable_scan?` defaults to false rather than the budget
simply applying to everyone: a source that restarts its enumeration each pass
would be cut off at the same point forever, never draining and never tombstoning.
`spec/services/sources/sync_spec.rb`'s `make_resumable` is the reference shape.

**That ordering inverts once a source's position is rows rather than a cursor.**
`Sources::Web` resolves an item row *after* the yield returns, not before, and
the reversal is deliberate — see the decision on item rows below. The rule above
still holds for any source whose position lives in memory.

**This build revealed a bug it did not cause.** `tombstone_vanished` reads an
unstamped document as gone, including one left unstamped by a `#reconcile` that
raised — so a failed item is tombstoned on a pass that reports `completed`. The
work is under "Surfacing sync failures" above, with the failure store it needs.

### Phase 2 — Contract groundwork — **built 2026-09-20**

Also independent of crawling, also worth landing before it.

- **`Source.authoritative_scan?`, defaulting true.** Absence from a Folder or
  BookStack scan means the item is gone. Absence from a crawl means it was not
  *reached* — a rate limit, a timeout, a boundary rule that changed, a nav
  redesign that orphaned a subtree. `tombstone_vanished` must consult the
  contract rather than special-case a type, or the first bad crawl tombstones
  half an archive.

  Note what that costs, accurately: not permanent loss. `#changed?` treats a
  `removed?` document as changed, and `ImportItemJob` re-asserts feed
  memberships, so anything still reachable is rebuilt by the next good scan. The
  cost is a window where the content is unsearchable and a full re-embed of
  everything affected — real, and worth a gate, but the gate is about not
  thrashing an archive rather than about rescuing it.

  It takes the run, because the answer is a property of the pass rather than of
  the source: `authoritative_scan?(run)`. The base implementation ignores its
  argument and returns true. `Sources::Web` answers it as a query over the visit
  rows of Phase 4 — **drained *and* cleanly resolved**. Draining alone is not
  enough: a URL that timed out is resolved, so the frontier can empty with a
  quarter of the site never actually reached. One timeout on a five-thousand-page
  site should not veto tombstoning; three hundred should.

  Considered and rejected: tombstoning only on positive evidence, i.e. the
  documents whose URL returned 404 or 410 this run. Cleaner in principle, but it
  misses the common case — a page dropped from the site's navigation while the
  server happily goes on serving it. Unlinked *is* gone, for a crawl. So the gate
  stays global, and what it decides is whether absence may be read as deletion.

- **Formalise the `config` / `state` split.** `sources.state` is in the schema
  and no type has ever written it, so the boundary has never been tested and
  nothing enforces it: `store_accessor :state, …` reads identically to
  `store_accessor :config, …` at the call site. The rule is **`config` is what a
  person set and a form may submit; `state` is what the source learned and no
  form may touch** — enforced by keeping `state` out of the permitted keys, not
  by convention.

  A second axis, which the first draft of this plan got wrong: **`state` is
  source-scoped and survives runs; what a *run* learned belongs to the run.** The
  original occupants proposed for `state` were the frontier cursor, budget
  consumed, and whether the last pass drained — all three run-scoped, and the
  mismatch is a live hazard, not a tidiness point. A swept run resets the run but
  not `sources.state`, so a crawl would resume mid-frontier under a fresh run id,
  drain, report authoritative, and tombstone every document the earlier run had
  stamped. All three now live on the run or are derived from it.

  What is genuinely left for `Sources::Web` is the sitemap's ETag/Last-Modified
  and the cached robots.txt with its crawl-delay. Those are facts about the site
  that outlive any one pass, which is what `state` is for.

- **Response-code stats on `SourceSync`.** One jsonb column, written *once* at
  terminal status by rolling up the run's item rows — `group(:disposition).count` —
  which are then reaped. Rows are the working set and the column is the durable
  summary; keeping the rows forever would mean tens of millions of them to answer
  "how did last Tuesday's crawl go", and accumulating the histogram in jsonb
  during the scan reintroduces the double-counting the rows exist to prevent.

  Keys are a mix, because half of what a crawl hits has no HTTP status: numeric
  strings for responses (`"200"`, `"301"`, `"404"`), named buckets for everything
  below or above HTTP (`"timeout"`, `"connection_failed"`, `"robots_excluded"`,
  `"too_many_redirects"`, `"nothing_readable"`). `Http` already retries
  `Faraday::TimeoutError` and `Faraday::ConnectionFailed`, so those arrive as
  exceptions rather than codes.

  This column is the only part of the crawl's bookkeeping that belongs to shared
  `SourceSync`, which is why it lands here and the table does not.

### Phase 3 — Verify — **done 2026-09-20**

Ran against real sources rather than fixtures, which is the point: phases 1 and 2
touch the engine every existing source runs through, and the crawler must not be
the thing that discovers they broke.

- **Folder, first scan** — `found=3 created=3`, all reaching `processed`.
- **BookStack, three consecutive re-scans of an unchanged source** — each
  `found=10 unchanged=10 removed=0`. The one that matters most: if `#redescribe`
  stopped stamping `last_seen_sync` on the unchanged branch, the second run would
  have tombstoned all ten.
- **BookStack, a genuinely changed page** — `updated=1 unchanged=1`, so the
  version token discriminates rather than marking everything changed.
- **Folder, a file added then deleted** — `found=3 unchanged=3 removed=1`, and
  the tombstone was complete: chunks destroyed, the feed membership retracted
  rather than deleted, the three siblings untouched.
- **No failure rows**, so the new `source_sync_items` path sat inert on healthy
  sources rather than masking anything.

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
4. **`source_sync_items`** — per-item outcomes that need to outlive a run's
   counters, belonging to the run:

   ```
   source_sync_id, external_id
   disposition   # nil = discovered, not yet attempted
                 # ok / failed / not_found / server_error / timeout /
                 # connection_failed / redirected / robots_excluded /
                 # nothing_readable
   status_code   # nullable: transport failures have none
   detail        # jsonb: error class and message, crawl depth
   unique index on [source_sync_id, external_id]
   ```

   **Rows are never a complete enumeration of what a run saw** — they are the
   items worth remembering. For Folder and BookStack that means failures only.
   A source that discovers its items writes one per item, because the row is how
   it remembers the work is done; that completeness is a property of how that
   source uses the table, not of the table.

   Discovering an item is an `insert_all` with `ON CONFLICT DO NOTHING` against
   the unique index, so dedup is a constraint rather than a discipline — no
   check-then-act, no in-memory seen-set, no race between two fetchers finding
   the same link. Attempting it updates the row in place. For a crawl the
   frontier is `where(disposition: nil)`, "drained" is that scope being empty, a
   pending row is an unmet obligation and a resolved one is proof an attempt
   happened and what came of it. Seeding a crawl is one insert; resuming is a
   query.

   Three consumers, only one of them the crawler: the frontier above, the
   tombstone exclusion under "Surfacing sync failures", and the per-item failure
   history that section wants to show. The last two are engine-wide, which is
   what pays for the table whether or not a second discovering source ever turns
   up.

   Reaping differs by disposition. A crawl's successes are bulk and disposable,
   rolled into the `SourceSync` histogram at terminal status; failures persist,
   because "this file has failed every scan for a week" is a question about a
   document over time.

   **Todo, not now: split `redirected` by whether the target was inside the
   boundary.** Purely diagnostic — the crawl loop does not care, because the row
   is resolved either way and whether a target row exists is already the complete
   record. Deferred because the payoff is a stat and the "Last scan" row is
   carrying eight of them already; crawl stats likely want their own block rather
   than a ninth column. Recorded so it is a choice rather than an oversight.

5. **`Sources::Web`** — `sitemap.xml` when the site has one, crawl as the
   fallback. `#each_item` conditional-GETs with stored ETag/Last-Modified; a 304
   replays the cached link set without re-parsing. `#read` re-fetches and
   re-extracts. `authoritative_scan?(run)` is the item-row query from Phase 2.

   **Resolve an item row *after* the yield returns, not before.** `#reconcile` is
   idempotent per item — a repeated yield finds the document, `changed?` is
   false, and it counts `unchanged` — so dying between the count and the resolve
   costs one inflated `found`/`unchanged` next pass. Resolving first inverts the
   failure into data loss: the row reads resolved, the document never got
   stamped, the frontier drains, `authoritative_scan?` says yes, and
   `tombstone_vanished` destroys its chunks. This is the inversion flagged in
   Phase 1; do not "fix" it back.

   **Parallelism is threads in one pass, not concurrent jobs.** `SyncJob` already
   holds `limits_concurrency key: source.id, to: 1`, so no second process can
   ever contend for these rows and the database needs no claiming — no
   `FOR UPDATE SKIP LOCKED`, no `claimed_at`. Fetcher threads do **HTTP only**;
   every query, insert and `yield` stays on the enumerating thread, which
   sidesteps connection-pool sizing and thread-safety entirely. Blocking IO
   releases the GIL, so this genuinely parallelises the part that waits. Four
   things that bite:

   - A `SizedQueue` for results, or fetchers run thousands of pages ahead of a
     reconcile that is enqueuing import jobs.
   - Extraction stays on the main thread: it is CPU, so it is GIL-bound, and in a
     worker it would only steal the lock from threads doing useful waiting.
   - Shut the pool down from `ensure` with a sentinel, not `kill` — `Sync` breaks
     out of `#each_item` on budget or abandonment, and leaked threads would go on
     fetching into a finished run.
   - Crawl-delay is a property of the host, not of a thread. Two fetchers each
     honouring the delay hit the site at twice the intended rate; it wants a
     shared mutex and a next-allowed-at.

   Worker exceptions come back as a result object carrying an error disposition.
   A thread that raises takes its exception with it until `join`.

6. **Politeness** — robots.txt and crawl-delay honoured, per-page
   `meta[name=robots]` too, an identifying User-Agent, one or two connections per
   host. GET and HEAD only.
7. **UI** — the source form, and the crawl stats on the run. `found` and URLs
   visited will differ and people will ask why, so both want hover text: *"Documents
   this scan found in the source"* against *"Pages the crawler fetched. Higher than
   found: redirects, dead links and pages with nothing readable are visited but
   produce no document."* The pattern already exists: `Views::Sources::LastScan`
   carries a `HINTS` hash and renders each label with a `title:` and a dotted
   underline, which is the only cue that there is anything to hover.
8. **SPA detection.** A client-rendered page extracts to near-zero text.
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
not about the archive, so it lives in `source_sync_items`. Note that
`Item#skip_reason` cannot serve here regardless: `Sync#reconcile` returns before
creating a document, and `count_uningestable` reads a skip as "the source has it,
we declined it" — the opposite claim to a 404.

The sharper version of the idea — create the Document but leave it unstamped, and
exclude it everywhere with a scope — does dodge the objection above, and fails on
what is downstream. A Document is the unit the ingestion pipeline operates on:
`status` defaults to `pending` and `#pipeline_statuses` counts over documents, so
every dead URL needs excluding there, in document lists, in counts, in search
scoping. That is "correct only if every query remembers the scope", which is the
same shape of mistake as hiding a link and calling it access control. And
`[source_id, external_id]` is unique, so a dead URL would permanently occupy
document identity space and need cleaning up if the page ever came back.

**Item rows, not a jsonb visited set.** The first draft of this plan chose jsonb
for the response-code stats because the requirement looked like *counts*. It is
actually *identity* — which URL, resolved how — because the crawl needs to know
what it has already fetched, and identity wants rows.

Reconstructing the visited set from `documents` alone does not work, and the
reason is the decision above: a URL that 404s leaves no document, so the URLs
that most need exactly-once accounting are precisely the ones the documents table
cannot remember. Splitting it — documents for the fetched, `state` for the failed
— puts one concept in two stores with different lifetimes and no constraint tying
them together. One table holds both, keyed to the run, with the unique index
doing the deduplication.

**Two ways to resume, and the source picks by what enumeration costs.** Both go
through `source_sync_items`; the difference is whether re-enumerating is cheap.

*Re-enumerate and skip* suits a source handed a listing — BookStack walks
`/api/pages` again each pass and passes over anything that already has a row.
Costs a listing walk per pass, which is ~100 API calls for 50,000 pages against
a per-item reconcile that dominates it. This is also the *safer* option where it
applies: a stored cursor into a paginated API is wrong if items are added or
removed between passes, because offset 500 is not the same offset 500 next time,
and the scan silently skips or repeats. Dedup by `external_id` cannot drift.

*Durable frontier* is required when enumerating and fetching are the same act.
A crawl cannot re-enumerate without re-crawling, so its pending rows are the
position. This is the expensive one, and Web is the only case in sight.

Neither is a cursor, and nothing run-scoped goes in `sources.state`. Note that
no source is resumable today — `resumable_scan?` has no overrides — so making
BookStack one is new capability rather than a conversion, and wants its own
reason to happen.

**No tombstone ceiling — trust the source.** Considered and rejected: refusing
to tombstone when a scan wants to remove more than some proportion of a
source. If a document is gone from the site it is gone from the site, and
second-guessing *why* buys nothing — a 404 or a redirect off the boundary is
the site answering, and volume does not change the answer. Deleting only part
of what a scan found missing also makes the outcome unpredictable and the
handling more complicated, which is a worse position than either extreme.

`authoritative_scan?` is not the same thing and stays. It is all-or-nothing
about whether a pass may be trusted *at all*, and it turns on a distinction
that does hold up: a timeout is the crawl failing to ask, where a 404 is the
site answering.

**If data-loss protection is ever wanted, it is retention, not refusal.** Soft
deletion and keeping N versions, so a user can retrieve an older version or
revert a batch — rather than a scan declining to act on what it found.

Most of that exists already. `#tombstone` sets `status: :removed` and keeps the
row, and retracted feed memberships are tombstones rather than deletions. What
is actually destroyed is `document.chunks`, so "keep N versions" is a question
about chunk retention, not document retention. The real gap is that no source
stores the bytes it read — `#read` re-fetches — so a document can only be
rebuilt while its page is still fetchable.

**`each_item` becomes a writer.** Resumption means persisting the crawl's
position mid-scan, and no existing source mutates anything while enumerating.
What it writes is item rows, not `sources.state` — the position belongs to the
run, and a row is durable the moment it is inserted, so there is no in-memory
cursor to flush from an `ensure`.

The standing hazard below is therefore no longer acute, but it still applies to
whatever writes `state` later — the sitemap ETag, the robots.txt cache.
`store_accessor` is a read-modify-write, reading the whole hash out of the
in-memory attribute, merging one key and writing it back. A stale instance
therefore reverts the *entire* hash rather than losing one key. Keep one instance
of the row per pass — `each_item` is an instance method, so `self` already is the
object `Sync` holds — and assign and `save!`. Not `update_column(:state, …)`,
which looks like the careful choice and is the worst of the options: it bypasses
dirty tracking and leaves the in-memory attribute stale for the rest of the pass.

The write ordering is safe as it stands, and worth recording so nobody re-derives
it: `Sync#call` is sequential — every `each_item` write lands during `scan`, and
`#finish` runs afterwards — and `#finish` assigns only `last_synced_at`, so with
`partial_updates` on under `load_defaults 8.1` its UPDATE never carries `state`.
There is no collision between the two.

**Per-URL bookkeeping lives on the Document, not in `state`.** ETag,
Last-Modified and the outbound link set go in `source_metadata`. Putting the link
graph in `state` would mean 30–80 links per page at ~60 bytes each — 15–25MB of
jsonb for a 5,000-page site, TOASTed and rewritten in full several times per
crawl. The same objection retired the frontier: `state` is source-scoped and
sized O(1), and anything O(pages) or belonging to one run lives elsewhere.

**Query strings are stripped, with no per-source allowlist** until one proves
necessary. Cycles are trivial (the item rows); infinite *spaces* are what kill
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

- **Chunks reach the model out of document order.** Observed 2026-09-20: asked
  what phase 4 contains, the answer led with SPA detection, which is step 8. The
  content was right and the sequence was lost — bad for any document whose order
  carries meaning, and this plan says outright that its steps are *"in this
  order, because the first three are pure functions"*.

  The fix is a sort at prompt assembly, not in retrieval. `Fuse` returns hits
  best-first and assigns citation handles 1..n in that order, which is correct
  for the results list and must stay; the chunks handed to the model want
  grouping by document and ordering by `chunks.position`, which already exists
  and is unique per document. The model then sees handles out of sequence, which
  is fine — they identify, they don't order.

  Overlap between chunks partly masks this by letting the model stitch on
  duplicated text, which is a worse mechanism than simply sending them in order.

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
