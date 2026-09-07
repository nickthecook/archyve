# Todo

Work that is known, shaped, and deliberately not done yet. Decisions that shape
the system live in `architecture.md`; this is the queue.

## Surfacing sync failures to the user

**Problem.** A sync can fail in three quite different ways, and today only the
first is visible:

1. **The scan failed.** `Connectors::Sync` records `status: "failed"` and the
   exception on the `ConnectorSync` row, and the connector page shows it. This
   case is done.
2. **The scan succeeded, but individual items failed.** Counted in
   `failed_count` and shown as "errored", but *which* items and *why* is only in
   the Rails log. The user sees "3 errored" with no way to learn which three.
   (Note these are bookkeeping failures inside `reconcile` — the scan never reads
   a file. Read and extraction failures land on the *document*, and want the same
   treatment from a different angle.)
3. **The worker died mid-scan.** The run stays `running` forever. The connector
   page flags it as stalled after an hour, but nothing recovers it and nothing
   explains it.

The user's question in each case is the same: *was this transient — do I just let
it sync again — or is it something I have to fix?* Answering that needs the error
text, per item, kept somewhere the UI can read.

**Shape of the work.**

- **Per-item failures need a home.** Options: a `connector_sync_items` table (a
  row per failure: external_id, error class, message, occurred_at), or a jsonb
  `failures` column on `connector_sync` capped at N entries. The table is the
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
  "worker did not report back", and leaves the connector free to sync again.
  Solid Queue's own `Batch.sweep_stalled` is the model for the shape, though the
  bookkeeping here is ours.
- **A place to look.** The connector page shows the last run; failures across
  runs probably want their own view ("documents that aren't ingesting"), since
  the natural question is about a *document* over time, not a *run*.

**Related, already handled:** a document whose ingest failed is retried by the
next scan — `Connectors::Sync#changed?` treats `failed` as changed. So the
failures above are visible-but-self-healing on the next interval, which is why
this is a todo and not a bug.

## Later

- **Connector config encryption.** `connectors.config` is plain jsonb. Fine for a
  path; ActiveRecord Encryption needs wiring before the first connector that
  holds credentials (S3 keys, a Bookstack token).
- **Configurable file extensions per folder connector.** Note the hazard: a file
  dropping out of the allowed list is not a file that left the source, so
  narrowing the list must go through the same `skip_reason` path that
  `max_file_size` uses, or it will tombstone documents.
- **Large trees scan in one job.** `Connectors::Sync` walks the whole directory
  in a single `SyncJob`. Fine for thousands of files; a million would want
  chunked or resumable scanning.
- **Who may configure connectors.** Open question from `architecture.md` — likely
  an app-admin role, distinct from per-collection admin, since connectors are
  global producers. Blocked on auth.
