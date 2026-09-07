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
  bookkeeping here is ours.
- **A place to look.** The source page shows the last run; failures across
  runs probably want their own view ("documents that aren't ingesting"), since
  the natural question is about a *document* over time, not a *run*.

**Related, already handled:** a document whose ingest failed is retried by the
next scan — `Sources::Sync#changed?` treats `failed` as changed. So the
failures above are visible-but-self-healing on the next interval, which is why
this is a todo and not a bug.

## Later

- **Unscoped lookups still outstanding.** From the 2026-09-07 sweep. Each is
  deliberate at this stage, listed so they aren't rediscovered one report at a
  time:
  - `SourcesController#set_source` finds any source by id. There are no
    per-source grants yet; the global `operator` role is the only gate.
  - `DocumentsController#show`, and the document lookups in
    `CollectionMembershipsController` and `UnsortedController#assign`, are
    unscoped by id. Consistent while `/documents` is operator-wide and there are
    no per-document grants — revisit if document visibility ever narrows.
  - `UnsortedController#index` lists every unfiled document to any operator,
    rather than only those from sources they own. That needs per-source grants
    (they don't exist yet) — a folder source has no owner, so scoping it now
    would hide unfiled documents from everybody. `Document.reachable_by` is
    written to match this: operators reach unfiled documents deliberately.

- **A stored URL per document.** `Source.user_accessible_links?` and
  `#document_url` exist but nothing returns true, because neither of the two
  source types can produce a followable address. The first that can (Bookstack,
  an object store with a console) needs `Source::Item` to carry a URL and
  `documents` to store one — deliberately not added ahead of something that can
  populate it.
- **Source config encryption.** `sources.config` is plain jsonb. Fine for a
  path; ActiveRecord Encryption needs wiring before the first source that
  holds credentials (S3 keys, a Bookstack token).
- **Configurable file extensions per folder source.** Note the hazard: a file
  dropping out of the allowed list is not a file that left the source, so
  narrowing the list must go through the same `skip_reason` path that
  `max_file_size` uses, or it will tombstone documents.
- **Large trees scan in one job.** `Sources::Sync` walks the whole directory
  in a single `SyncJob`. Fine for thousands of files; a million would want
  chunked or resumable scanning.
- **Per-collection and per-source grants.** The global role is built; the
  second axis isn't. Needs `collection_users`, `source_users`, retrieval scoped
  to readable collections, and the feed picker moved to the collection page.
  (The "who may configure sources" question is settled: `operator`.)
