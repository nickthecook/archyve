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

- **A stored URL per document.** `Source.user_accessible_links?` and
  `#document_url` exist but nothing returns true, because neither of the two
  source types can produce a followable address. The first that can (Bookstack,
  an object store with a console) needs `Source::Item` to carry a URL and
  `documents` to store one — deliberately not added ahead of something that can
  populate it.
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
