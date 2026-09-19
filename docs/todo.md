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
  chunked or resumable scanning.
- **Per-collection and per-source grants.** The global role is built; the
  second axis isn't. Needs `collection_users`, `source_users`, retrieval scoped
  to readable collections, and the feed picker moved to the collection page.
  (The "who may configure sources" question is settled: `operator`.)
