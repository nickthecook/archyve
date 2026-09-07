# Archyve 2 — Architecture & Decisions

A rebuild of the Archyve RAG application. This document records the stack and
the reasoning behind each major decision, so the "why" survives the "what".

Status: pre-implementation. Decisions below are settled; open items are marked.

## Guiding goals

- **Clean, non-ERB UI.** ERB was the worst part of the old app — verbose,
  error-prone, and awkward with Hotwire. Eliminate it.
- **Simple to deploy.** The old app ran a zoo of containers. Cut that down
  hard. Target: app + Postgres, plus one extraction sidecar.
- **Self-hosted / open-source ethos.** Local-first (Ollama), no dependence on
  SaaS AI credits to run.
- **Real-time.** Streamed chat responses and live document-processing stats.
- **Source-first ingestion.** Documents come primarily from external sources
  (local dir, S3, Bookstack, …) via a core source framework; manual upload is
  the exception, not the norm.

## The stack

| Layer | Choice | Notes |
|-------|--------|-------|
| Framework | **Rails 8** (monolith, not API-only) | Keeps auth, routing, forms, real-time cohesive |
| Views | **Phlex** (`phlex-rails`) | Views as composable Ruby objects — the ERB replacement |
| Real-time / JS | **Hotwire** (Turbo + Stimulus) | Turbo Streams over Action Cable for push updates |
| CSS | **Tailwind** (`tailwindcss-rails`, standalone CLI) | Single binary, **no Node** |
| JS bundling | **importmaps** | No bundler, **no Node** |
| Database | **Postgres + pgvector** (`neighbor` gem) | HNSW index |
| Embeddings | **`nomic-embed-text`** (Ollama), **768 dim** | Long 8192-ctx suits structure-aware chunks; fully open |
| Blob storage | **Active Storage — Disk** to start | S3-compatible later via **Garage** (NOT MinIO) |
| Background jobs | **Solid Queue** | Backed by Postgres — no Redis |
| WebSockets | **Solid Cable** | Backed by Postgres — no Redis |
| Cache | **Solid Cache** | Backed by Postgres — no Redis |
| Auth | **Rails 8 built-in** (`generate authentication`) | Over Devise, unless OAuth/SSO needed later |
| LLM client | **RubyLLM** | Multi-provider, tool calling, streaming |
| Document extraction | **Docling** (`docling-serve` sidecar) | Structure-aware; the one extra container |
| Testing | **RSpec** | House style applies |
| Deploy | **Kamal 2** | Ships with Rails 8 |

Net container count: **app + Postgres + Docling sidecar.**

## Why Rails monolith over Rails API + Svelte SPA

Considered an API-only Rails backend with a Svelte/SvelteKit frontend. Rejected
for this app because:

- **Deploy simplicity is a primary goal.** The SPA path adds a Node runtime
  and/or a separate asset server — the opposite direction. The monolith with
  Solid* services + Tailwind standalone + importmaps needs **no Node at all**.
- **The real-time needs are server-push, not rich-client-state.** Streaming
  chat tokens and live pipeline stats map naturally onto Turbo Streams; they
  don't call for a heavy client framework.
- **Learning Svelte was a means, not an end.** Not worth the added moving parts
  here. (Reverse-proxying both apps under one origin would have removed most of
  the CORS/cookie friction, but not the multi-process/deploy overhead.)

Note on Herb / ReActionView: it's still ERB (an HTML-aware ERB engine + tooling),
so it doesn't address the ERB-verbosity objection. Phlex does.

## Phlex + Hotwire

Phlex removes the ERB-partial sprawl that made Turbo feel heavy before:

- A Turbo Frame is a component wrapping children in `turbo_frame_tag`.
- A Turbo Stream response renders a **component**, not a `.turbo_stream.erb`.
- `dom_id` and frame IDs become methods/constants — no magic strings across files.

**One rough edge:** Turbo's model-level broadcast helpers (`broadcast_append_to`,
`after_create_commit`) assume partials via `to_partial_path`. Prefer **explicit
broadcasts** from the job/service doing the work (render the component to a
string, call `Turbo::StreamsChannel.broadcast_*`). This suits an imperative
pipeline anyway. Fallback if needed: a one-line `_x.html.erb` shim that renders
the component.

## Document processing

- **Extraction via Docling** (`docling-serve` HTTP sidecar). Chosen because
  document parsing is a genuinely hard problem best left to experts — the old
  app's parsing was "good enough" and needed real work.
- Docling returns a **structured document model** (headings, sections, tables,
  lists, reading order), not a flat text dump.
- **Structure-aware chunking is required** (via Docling's tokenizer-aware
  HybridChunker) so the model never has to reason about truncated
  paragraphs/sentences or guess overlaps.
- Persist structural metadata with each chunk (source page, heading path, etc.)
  — useful for showing the model/user *where* a retrieved chunk lives.
- Pipeline flow: Rails → Solid Queue job → POST to docling-serve → persist
  chunks → embed. Model documents/chunks with explicit per-stage status so
  progress can be broadcast in real time.

## RAG as a tool (not blind context stuffing)

Retrieval is exposed to the model **as a tool** it can call, rather than
prepending document fragments to every prompt. Rationale: current models are
good at directing their own search, and tool-driven retrieval beats
indiscriminate context injection. RubyLLM's tool-calling support underpins this.

## Multi-provider strategy & pgvector implications

**Separate the two provider roles — pgvector only constrains one of them.**

### Generation (chat) provider — freely swappable
Stateless per request; Ollama / OpenAI / Azure OpenAI differ only in base URL,
auth header, and path convention. That's a **client-layer** concern (RubyLLM or
a thin adapter). Azure's deployment-in-path + `api-key` header is the fiddliest
but still just adapter config. **pgvector is uninvolved.** Can switch freely,
even mid-conversation. (Starting all-Ollama avoids this variety for now.)

### Embedding provider — the sticky one
Two hard facts:
1. **A pgvector column has a fixed dimension** (e.g. `nomic-embed-text` 768,
   `mxbai-embed-large` 1024, OpenAI `text-embedding-3-small` 1536). One HNSW
   index per dimension.
2. **Embeddings from different models are not comparable** — different vector
   spaces. A query embedded with model B cannot search a corpus embedded with
   model A.

Therefore the **embedding model is effectively a corpus-wide setting**, and
changing it means **re-embedding the entire corpus**. This is inherent to RAG,
not a pgvector limitation.

Starting choice: **`nomic-embed-text` (768 dim)** via Ollama. Chosen over
`mxbai-embed-large` (1024) mainly for **context length**: nomic's 8192-token
window suits Docling's structure-aware chunks (embed whole sections), whereas
mxbai's 512-token limit forces small chunks and fights structure-aware chunking.
nomic is also fully open (weights + training data), US-origin (Nomic AI), and
smaller vectors. mxbai (from Mixedbread, 🇩🇪 — not Chinese; BGE/GTE are the
Chinese ones) had a slightly higher MTEB score, outweighed here by context. Note:
both date to early 2024 — reassess vs newer open embedders (nomic-embed-text-v2,
snowflake-arctic-embed, bge-m3, Qwen3-Embedding) before scaling. Honor nomic's
task prefixes (`search_document:` / `search_query:`) at index and query time.

Design consequences:
- Store the **embedding model id + dimension** with every vector; validate query
  embeddings match the active corpus and fail loudly on mismatch.
- Make **re-embedding a first-class Solid Queue job** ("change model → re-embed
  all chunks"), treated as normal, not an emergency.
- **Pick the starting embedding model now** to size the column. Starting with
  Ollama: `nomic-embed-text` (768) or `mxbai-embed-large` (1024).
- To run **two embedding models simultaneously** (A/B or zero-downtime
  migration), use a **separate table/column per model** — never mix dimensions
  in one column.

## Source-first ingestion

The **primary** ingestion method is **sources** — connections to external
storage systems (local directory, S3, Bookstack, …) — not manual upload.
Manual upload still exists but is the exception, not the expected long-term
pattern. The source framework is **core to the app**, not a bolt-on.

Two layers, kept separate:

1. **`Source` (persisted config)** — a configured source instance: `type`
   (`local_dir` / `s3` / `bookstack` / `manual_upload` / …), name, **encrypted**
   credentials/config (ActiveRecord Encryption), owning scope, sync schedule,
   and sync **cursor/state**.
2. **Adapter (stateless code)** — the type-specific driver, in a **registry**
   so a new source = one class + registration. Uniform interface:
   - `list(cursor:)` → source items, each with a stable **`external_id`** and a
     **version token** (etag / last-modified / content hash / Bookstack
     revision) + metadata.
   - `fetch(item)` → raw bytes + content-type (streamed).
   - capability flags: `supports_incremental?`, `supports_webhooks?`.

> **As built (2026-09-06), these two layers are one.** The STI subclass is both
> the persisted config and the driver: `Sources::Folder` holds its config in
> `config` jsonb *and* implements the interface. The registry is `Source::TYPES`.
> Splitting them would have bought a stateless-adapter seam that nothing yet
> needs, at the cost of a second parallel hierarchy — so the word "adapter" does
> not appear in the code, and the interface is called the **sync contract**:
> `#each_item` (yielding `Source::Item`) and `#read(external_id)`. Revisit if a
> source ever needs its driver without a database row behind it. The two
> capability flags above aren't built either; `.supports_sync?` is the only one
> so far.

**Provider-agnostic sync engine.** Diffs current source items against stored
`Document`s (keyed by `source_id` + `external_id`) → create / update / delete:
- **Version token unchanged → skip.** Critical: re-ingest means re-embed (the
  expensive op), so change detection keeps large syncs cheap.
- **Version changed → re-ingest** that one doc (re-extract, re-chunk, re-embed).
- **Item gone from source → tombstone** and remove its chunks.

**Scheduling:** poll-first via Solid Queue recurring jobs, per-source
interval. Webhooks/push (S3 events, Bookstack webhooks) added later behind
`supports_webhooks?` — same sync engine, different trigger.

**Manual upload is just a `manual_upload` source** — keeps a single ingestion
+ progress code path.

Data-model impact: `Document` gains `source_id`, `external_id`,
`source_version`, `source_metadata`, and a lifecycle status. Sources get
first-class UI (list / configure / sync-now / per-source processing stats),
feeding the real-time pipeline-stats feature.

### Sources, Documents, and Collections (relationship model)

Decided: **sources produce Documents; collections are a membership / query /
access layer over Documents.** A source is NOT owned by a collection.

- `Document` is owned by (produced by) a **source**.
- `Collection ↔ Document` is **many-to-many**. A document can belong to many
  collections; its bytes, chunks, and **embeddings are stored once**.
  Collection-scoped search is a **filter** over eligible documents — never
  duplicated storage or re-processing.
- **Rationale:** source-per-collection would mean duplicating the source,
  re-processing every document, and storing duplicate embeddings to share a set
  across collections. That cost is far worse than the relational complexity of
  decoupling. (Model inspired by Onyx: one source → many "document sets".)

Routing (how documents land in collections):
- A source **"feeds" one or more collections** (`source ↔ collection`
  join). Newly-produced documents **auto-join** those collections on sync.
- Plus manual add/remove of individual documents to/from a collection.

Membership is **materialized**, not computed at query time:

```
collection_memberships(collection_id, document_id, source, removed_at)
  source:     :source | :manual
  removed_at: NULL = active member; set = tombstoned (won't be re-added by sync)
```

- **Sync** ensures a `source` row exists for each produced doc in each
  fed collection — UNLESS a tombstoned row exists (`removed_at` set). This is the
  "removed from collection" list, living in the membership table rather than as a
  separate overlay, so there is no per-query overlay computation.
- **Manual add** → `manual` row. **Manual remove** → set `removed_at` (never
  hard-delete), so the next sync won't re-add it. **Re-add** → clear `removed_at`.
- **`source` disambiguates the edge case:** if a source stops feeding a
  collection, retract `source` memberships but keep `manual` ones.

Deletion & lifecycle:
- **No deleting individual documents** — they are source-owned. Remove from the
  source and re-sync (tombstones them). Keeps the corpus a faithful mirror.
- **Remove-from-collection = membership tombstone only** (see above) — never
  deletes the document or embeddings (it may live in other collections).
- **Deleting a source** cascades to its documents + chunks + embeddings.

Query-time:
- The **RAG retrieval tool operates within a collection** (or the set the
  user/chat can access) — this is where access control is enforced.
- **Collection-scoped search = filtered ANN** over the materialized membership
  join (`document_id IN (active members of collection)`). HNSW + a selective
  filter can under-return / slow down. Performance plan, in order:
  1. Filtered ANN via the membership join — the baseline; likely fine at
     self-hosted scale. **Measure before optimizing.**
  2. **pgvector iterative scan** (0.8+) — main lever; walks the graph until
     enough rows pass the filter. No architectural cost.
  3. Over-fetch + post-filter (top-N > K, then filter).
  4. Partition **only by a single-membership key** (owner / workspace / tenant),
     never by collection.
- **Do NOT partition/duplicate embeddings per collection** — that reintroduces
  the exact triple-storage/processing cost the many-to-many model avoids. Reserve
  per-collection duplication only as a localized escape hatch for a proven hot
  collection, never as the default.

## Multi-user & access control

Two axes, not one.

**Global role (built 2026-09-07)** — `users.role` ∈ `user` / `operator` /
`admin`, an integer enum so the values are *ordered*. This is a **capability
ceiling**, and the gate on everything that isn't scoped to a collection:

- `user` — chat and search. No management surfaces at all.
- `operator` — + sources, collections, documents, filing.
- `admin` — + settings and people, everywhere, needing no per-object grant.

Enforced by the `Authorization` concern (`require_role :operator`), beside the
`Authentication` one. Views filter affordances with `may?(:operator)` — the nav
in `Views::Chrome::NAV` and the landing's facets both do — but hiding a link is
not access control; the controller gate is.

Because the role is a ceiling, **self-granting is structurally harmless**: an
operator can create a collection and make themselves its admin and still never
reach settings. The two axes combine with `min`.

The last admin can neither be demoted nor deleted. That guard is a validation
and a `before_destroy` on `User`, not a controller check, so no path — console,
seeds, a future API — can leave Archyve unadministrable.

**Reaching a document (built 2026-09-07).** Whether a reader gets a link or a
download is a property of the **source**, not of the reader's role
(`Source.user_accessible_links?`):

- A source that can hand out an address the reader's browser can follow gets
  linked to. The reader lands on the live document with whatever permissions
  and history the source keeps.
- One that can't is downloaded from Archyve. A folder can't — the file lives at
  a path on the Archyve host and no reader is sitting at that machine — and
  neither can manual upload. Both are download-only, and nothing returns true
  yet.

So chat and search behave identically for an operator and a plain user. An
operator's extra reach is *browsing* the archive, a different entry point:
`/documents` is `operator`, the download is not. That is friction, not a
boundary — a reader holding a document id can fetch it — and it is deliberate.
The archive's contents are as reachable as the personas that answer questions
about them; what the role prevents is enumeration.

Downloads stream through the controller rather than redirecting to an Active
Storage blob URL: a signed blob URL is reachable by anyone holding it, which
would put the archive one forwarded link away from anybody.

**Per-object grants (not built).** Access to documents is granted **through
collections**.

- **`collection_users`** join: `user ↔ collection` with `role` ∈
  `read` / `read_write` / `admin`.
  - `read` — query the collection.
  - `read_write` — + manually add/remove document memberships, trigger sync.
  - `admin` — + edit collection settings, manage feeds & user roles, delete.
- **Multi-collection query:** retrieval takes a **set of collection IDs** from
  day one (same query shape as one — `document_id ∈ (active members of ANY of the
  user's readable selected collections)`, **de-duplicated**). This is cheap
  insurance against baking single-collection assumptions from UI → DB. **UI
  starts single-select**; a multi-select widget is a self-contained later view
  change with no ripple into retrieval/DB. If single-collection turns out to be
  all we want, nothing is lost — just never ship the widget.
- **Who may create/configure sources: `operator`** (settled 2026-09-07). Sources
  are global producers, so they are gated by the global role rather than by any
  per-collection grant. Changing which collections a source *feeds* is a
  separate question and belongs to the collection: ownership of what readers see
  sits with the collection, not with the source producing it.
- A source-level grant, when it lands, needs only `operator` / `admin` — a
  source `user` role has no meaning, since seeing a source is implied by seeing
  a collection it feeds.

## Streaming & transports

**Principle: keep retrieve-generate-stream in a transport-agnostic generation
service** that emits provider-neutral text/token deltas. Then every transport is
a thin adapter over the same core.

- **Built-in chat UI + pipeline stats: Turbo Streams over Action Cable
  (Solid Cable).** Unified with Hotwire, free reconnection, and multi-tab /
  multi-device conversation sync.
- **Token streaming caveat:** Solid Cable is DB-backed and polls (~100ms), so
  broadcasting per token means many tiny inserts + a latency floor. **Buffer
  tokens** (flush every ~50–100ms or N tokens) — costs nothing perceptible,
  slashes DB load. Fallback if latency/load ever bites: **SSE via
  `ActionController::Live`** (lowest latency; holds a Puma thread per stream).
  Cheap to switch to *because* the generation core is transport-agnostic.
- **Ordering (learned from Old Archyve):** small buffers caused out-of-order
  fragments there. Cause is almost certainly **async broadcast delivery racing**
  (Action Cable worker-thread pool; `broadcast_*_later` fans out to concurrent
  jobs), not the client. Rules:
  - **Broadcast synchronously from the single generation loop** — one job/thread
    calling `broadcast_append_to` inline. **Never `broadcast_*_later` for
    tokens.** (Solid Cable's ordered autoincrement ids + ordered synchronous
    inserts should be far more deterministic than the old Redis async path.)
  - **Put a monotonic sequence number on every delta** so the client can
    assert/repair order and reordering is detectable, not guessed at.
  - Avoid "raw text over Cable + custom JS append": keeps the pub/sub reorder
    risk AND spends the no-JS budget. If we want raw-text streaming, use SSE
    (single ordered TCP stream — structurally cannot reorder).
- **Later feature — OpenAI-compatible SSE API** (`/v1/chat/completions`,
  `stream: true`): a de-facto standard that lets backend-agnostic chat UIs
  (Open WebUI, LibreChat, editor plugins) use Archyve as a **RAG-augmented
  backend**. Mismatch to solve: that API has no "collection" concept — encode it
  in the `model` field (`archyve/<collection>`) or a custom param, resolved
  server-side. Not v1, but the service-layer design must not preclude it.
  - **Successor to Old Archyve's OPP (OpenAI Proxy Port).** OPP was a transparent
    prompt-rewriter (intercept → stuff RAG results in → pass through). With
    RAG-as-a-tool that model no longer fits — instead this endpoint is a **thin
    adapter over the same agentic generation service**: Archyve runs its own
    configured model with the RAG tool available, lets the model decide when/what
    to retrieve, and streams the completion back. Transparent *to the client*
    (still just a chat completion), but Archyve is a full agent behind it, not a
    prompt-mangler. No separate "should I augment?" classifier — that's just the
    model's tool-calling judgment. One more reason to keep the agent loop in the
    transport-agnostic service.

## Open items (to settle during implementation)

- Who may create/configure sources (app-admin vs a dedicated role).
- Exact `Source` config UI/validation per adapter type.

## Resolved decisions (previously open)

- **Source ↔ collection:** sources produce Documents; collections are a
  many-to-many membership/query/access layer. Sources "feed" collections;
  documents auto-join fed collections + manual add/remove. (See relationship
  model above.)
- **Sync trigger:** poll-first via Solid Queue recurring jobs. Webhooks deferred
  as a later headline feature (same sync engine, alternate trigger).
- **Embedding model:** `nomic-embed-text` (768) via Ollama — see rationale above.
- **Blob storage:** Active Storage Disk to start; Garage (S3-compatible) later.
- **Collection roles:** `read` / `read_write` / `admin` via `collection_users`;
  multi-collection query over the accessible selected set (deduplicated).
- **Streaming transport:** Turbo Streams over Action Cable (buffered tokens) for
  the built-in UI; generation kept transport-agnostic so SSE / an
  OpenAI-compatible API can be added later.
