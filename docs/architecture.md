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
| Auth | **Rails 8 built-in** sessions + **OIDC** (hand-rolled) | Over Devise; SSO added 2026-09-19 without it — see Single sign-on |
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

### As built (2026-09-11): `InferenceServer` + `InferenceModel`

Provider config lives in two tables rather than in the environment. An
**`InferenceServer`** is a URL plus credentials — STI, the same shape as
`Source` (`TYPES` registry, `config` jsonb via `store_accessor`, a separate
**encrypted `api_key` column**, never a secret inside the jsonb). An
**`InferenceModel`** is one model on one server, with `kind` (`chat` /
`embedding`), `dimensions`, `context_window` and `supports_tools`.

**Where the `kind` / capability line falls.** `kind` is *which call drives the
model* — RubyLLM's `complete` / `embed` / `paint` / `transcribe` verbs. Anything
that is a different *input* to the same call is a capability column beside
`supports_tools`, not a kind. So `gpt-4o` accepting images and `gemma4`
accepting audio are both still `kind: :chat`; `whisper` and `dall-e` would be
new kinds if Archyve ever transcribes or paints. Ollama draws the same line for
us — gemma4 reports `["completion", "vision", "audio", "tools", "thinking"]`,
where `completion` is the kind and the rest are capabilities of it. Get this
backwards and `gpt-4o` ends up filed under `:vision`, invisible to chat.

Four consequences worth knowing before touching this:

- **`RubyLLM.configure` no longer sets provider keys.** RubyLLM's provider
  settings are global and single-slot — one `config.ollama_api_base` per process
  — so two Ollama hosts could never coexist through it, and an initializer
  cannot read the database anyway. Each server builds its own
  `RubyLLM::Context` in `#llm_context`, and inference goes through that.
- **RubyLLM does not speak native Ollama.** `RubyLLM::Providers::Ollama`
  subclasses the OpenAI provider and talks to `/v1/models`, which reports only
  ids — and it fills the gap by hardcoding the same capability list onto every
  model, so through that endpoint `nomic-embed-text` claims it can call
  functions. Discovery therefore goes direct to `GET /api/tags` +
  `POST /api/show`, which declare `capabilities` (`embedding` vs `completion`,
  and `tools`) along with context length and embedding dimensions. Inference
  still goes through RubyLLM.
- **OpenAI discovery is inference, not report.** An OpenAI-compatible
  `/v1/models` returns ids and nothing else, so `InferenceServers::OpenAI`
  classifies with RubyLLM's `Capabilities.model_family` id patterns: chat,
  embedding, or a `skip_reason` for families Archyve has no kind for (image,
  transcription, speech, moderation, legacy completion). Those skips retire
  themselves as kinds are added. An id RubyLLM has no pattern for lands in
  family `other` and yields `kind: nil` — the picker then asks. **Import
  requires tool support**: a chat model that can't call tools is listed but
  disabled, since retrieval reaches the model as a tool and one that can't call
  it can never touch the archive. Embedding models are exempt — they call
  nothing. `nil` (no pattern) is treated as "no" here, which hides dated
  snapshots like `gpt-4-0613`; their undated equivalents are usually in the
  list, and *Add manually* takes anything. Loosening it means blocking only
  known-`false`.
- **The embedding model is guarded by the corpus, not by a flag.**
  `InferenceModel` refuses an embedder while vectors produced by a *different*
  model exist, because those are what a switch would strand. With an empty
  corpus it's just a setup step, and re-declaring the model the corpus is
  already full of is not a change at all — which is how an install predating
  these rows describes itself. `dimensions` is validated against
  `Embedding::DIMENSIONS`, so a model that cannot physically fit the
  `vector(768)` column can never become the archive's embedder.

Nothing is seeded unless `OLLAMA_API_BASE` is set: **zero servers is a
legitimate state**, and the pages say "not configured" rather than reporting an
unreachable localhost nobody asked for.

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

**Endpoints (2026-09-17).** A third layer *was* added, and it is worth saying
why it earns itself where the adapter split above did not. An `Endpoint` is the
server a source pulls from plus the credentials for it: `Source` optionally
`belongs_to` one, and an endpoint `has_many` sources.

The justification is cardinality. Ten Bookstack sources against one wiki — one
per shelf, each feeding a different collection — should mean typing the token
once and rotating it once. The adapter seam bought a stateless driver nobody
needed; this seam deduplicates a secret, which is a job.

- **STI**, with its own `TYPES` registry and per-type view components reached
  through a constant the subclass names — never `constantize` on a type string.
- **Two columns, and the split matters.** `config` jsonb stays readable in SQL
  (base URL, a token *id*) so an admin list can name a host without decrypting
  every row; `credentials` is an encrypted `text` column holding JSON and
  nothing but secrets. Not jsonb: encrypting it would forfeit exactly the
  querying and indexing that are jsonb's reason to exist.
- **Nullable on `Source`, permanently.** Folder reads local disk and
  ManualUpload is fed by a person. An `Endpoints::Local` singleton would make
  the column `NOT NULL` at the cost of a credential-less row in every endpoint
  list.
- **What's recorded is the last access, not health.** Every sync accesses the
  endpoint, so `accessed_at` / `access_error` are a byproduct of ordinary work
  rather than something probed on a schedule — both describe the same event, and
  the error is nil when that access worked. `#access` runs the subclass's
  `#access!` and records the outcome; it exists for the one moment syncing
  doesn't cover, when an admin has just typed a token.

- **A source names the endpoint type it takes**, once, as
  `.endpoint_type` — `Sources::Bookstack` takes an `Endpoints::Bookstack` and
  nothing else. One declaration drives both the validation and the options the
  endpoint picker offers; a source whose `.endpoint_type` is nil reads something
  local and needs no endpoint at all.

Which options go on the endpoint and which on the source: **does changing it
invalidate what we already ingested?** Base URL and token move you to a
different server or identity → endpoint. Selectors, sync interval, OCR change
what you take and how → source.

**Provider-agnostic sync engine.** Diffs current source items against stored
`Document`s (keyed by `source_id` + `external_id`) → create / update / delete:
- **Version token unchanged → skip.** Critical: re-ingest means re-embed (the
  expensive op), so change detection keeps large syncs cheap.
- **Version changed → re-ingest** that one doc (re-extract, re-chunk, re-embed).
- **Item gone from source → tombstone** and remove its chunks.
- **Description rewritten whenever it differs, on *either* branch.** An item's
  title, `path`, `url` and metadata are what the source *says about* it, not its
  content, so they are not the version token's business. Renaming a Bookstack
  book moves the path of every page in it with zero fetches; folding the path
  into the token instead would refetch all of them to learn the bytes were
  identical.

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
reach settings.

The last admin can neither be demoted nor deleted. That guard is a validation
and a `before_destroy` on `User`, not a controller check, so no path — console,
seeds, a future API — can leave Archyve unadministrable.

### Single sign-on (built 2026-09-19)

Keycloak is the IdP; Archyve is a confidential OIDC client doing the
authorization-code flow with PKCE. Hand-rolled against Faraday
(`Sso`, `Sso::Client`, `Sso::Identity`) rather than OmniAuth: one known
provider, authentication only, and OmniAuth's Rack middleware would have meant
provider settings in an initializer — the thing `config/initializers/ruby_llm.rb`
argues against at length.

**Identity is keyed on `sub`, not email.** `sub` is the IdP's permanent
identifier; email is what people change. Matching on email would hand a renamed
user a second empty account, and would hand a *reused* address somebody else's
history. Email decides exactly one thing: the one-time link on first sign-in,
and only when the IdP asserts `email_verified`. Anything less would mean an
attribute set at the IdP could inherit the break-glass admin's account.

**The group check is a login gate, not role mapping.** Keycloak asserts a
`groups` claim; Archyve refuses anyone without `ARCHYVE_SSO_GROUP`. Everyone it
provisions arrives as a plain `user` with no grants — the role ladder above
stays Archyve's business. Refusal also destroys that user's existing sessions,
because revoking a group has to reach a browser that is already signed in.

**The ID token's signature is not verified,** which OIDC Core §3.1.3.7(6)
permits when the token arrives directly from the token endpoint over TLS with
client authentication. That is this exchange, so there is no JWKS to fetch,
cache or rotate. `iss`, `aud`, `exp` and `nonce` are still checked.

**Sessions have an absolute 1-day lifetime** (`Session::LIFETIME`), not a
sliding one. It is the upper bound on how long a revoked user keeps working, and
a sliding window would mean an active revoked user never hits it. A constant
rather than a `Setting`: that bound shouldn't be widenable from a browser.

**Sign-out ends the Keycloak session too** for SSO sessions, via
`end_session_endpoint` with the stored `id_token_hint`. Without it, "Sign out"
followed by "Sign in with SSO" would silently sign the user back in. This is
realm-wide single logout.

**The break-glass admin is what makes an SSO outage survivable**, which is why
linking an existing account never clears its `password_digest`, and why the
password form stays reachable behind a disclosure on `/session/new`. An SSO user
has a NULL digest and cannot use that form at all — that is what stops the group
check being bypassable — and cannot set a password from `/account`.

**Configuration is all-or-nothing.** `Sso.configured?` requires all four of
`ARCHYVE_SSO_ISSUER`, `ARCHYVE_SSO_CLIENT_ID`, `ARCHYVE_SSO_CLIENT_SECRET` and
`ARCHYVE_SSO_GROUP`, so there is no state reachable by forgetting a variable in
which SSO is enabled but ungated. Unset, the button is hidden and both routes
refuse independently. The setup itself — Keycloak client, group, mapper, and the
proxy requirements — is in the README.

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
`/documents` is `operator`, the download is not. The download is nonetheless
scoped to what the reader could have been cited (`Document.reachable_by`), so
holding an id is not enough — what the role additionally prevents is
enumeration.

Downloads stream through the controller rather than redirecting to an Active
Storage blob URL: a signed blob URL is reachable by anyone holding it, which
would put the archive one forwarded link away from anybody.

**Per-source grants (built 2026-09-07).** `source_users` grants one person
standing with one source:

- `user` — may feed this source into a collection they administer.
- `operator` — + change its config, trigger a sync.
- `admin` — + manage its people, and delete it.

The `user` role is not "may read this source". It is "may draw on it", and it
exists because **configuring a source and drawing on it are different mandates
held by different people**. In an organisation IT owns the credentials and the
team owning a collection decides what feeds it. Without this role, letting a
collection's owner attach a source would mean handing them the credentials —
or routing every attachment through a system admin, which is a ticket per
collection rather than a grant per team.

(An earlier iteration had no `user` role here, reasoning that seeing a source
exists is implied by seeing a collection it feeds. That was circular: it assumed
the source was already attached. This is the grant that attaches it.)
- **Owning a source implies administering it.** A per-user upload source carries
  a `user_id` and no grant row; `Source#granted_role_for` returns `admin` for
  its owner, which is what keeps those working without a redundant row.
- Whoever adds a source is granted `admin` on it, as with collections.

**Feeding is governed by the collection, not the source**, because it decides
what the collection's readers see. It can be driven from either end:

- **From the collection** (`CollectionSourcesController`) — attaching needs
  `operator` on the collection *and any grant on the source*; detaching needs
  only the collection side, since you may always stop drawing on something, and
  a revoked source grant must not leave a collection permanently fed by
  something its owner can't detach.
- **From the source** (`SourcesController#selected_collections`) — offers only
  collections that person manages.

**Not every type can be fed from.** `Source.feeds_collections?` is false for
manual upload: its documents are filed one at a time by whoever uploads them,
choosing the collection as they go, so a standing feed would mean every file
that person ever uploads silently joins — which is not what "upload this to the
handbook" asked for. The predicate sits alongside `.supports_sync?` and
`.user_creatable?`, and `update_fed_collections` refuses regardless of which UI
asked, so the rule holds even if a screen forgets it.

Both go through `Source#update_fed_collections`, which files existing documents
into a newly fed collection and retracts the memberships it had asserted in a
dropped one. It **diffs the full list and tombstones everything absent from
it**, so both paths derive that list from the *source's* current collections
rather than from what the person can see. Without that, one operator saving a
shared source silently unfiles another team's documents.

**Retrieval scoping (built 2026-09-07).** Two questions about a document, kept
deliberately apart as `Document.retrievable_by` and `Document.reachable_by`:

- **Retrievable** — what a query may draw on. Strictly through collections: a
  document in no collection is in nobody's corpus. Governs search, and chat when
  it lands. This is where access control is enforced for retrieval.
- **Reachable** — what a person may open or download directly. Everything
  retrievable, plus everything produced by a source they manage. That second
  clause is what makes `/unsorted` work: an unfiled document is in no
  collection, so nothing retrieves it, but whoever manages the source that
  produced it can open it — and filing it is what they are there to do. It
  covers your own uploads too, since owning a source counts as administering it.

Admins are unrestricted on both. Scoping the download matters as much as scoping
the query: without it, retrieval scoping is bypassable by guessing an id.

Scope parameters resolve through the same filter. A `c[]` slug naming a
collection the reader can't see is **dropped rather than rejected** — erroring
would confirm the collection exists — and a `doc` id they can't read never
resolves to a title, so the scope label leaks nothing.

The `c[]` wire format has **three** states, not two: no `c` at all means the
whole archive (the landing bar, a link that never mentioned collections); `c[]`
carrying slugs means those collections; and an *empty* `c[]` means nothing at
all. The chat scope picker ticks every collection by default and always posts a
blank `c[]` alongside what's ticked, so unticking everything starts a chat with
no retrieval tool at all — a picker that searched everything while showing
nothing ticked was claiming the opposite of what it did.

**Per-collection grants (built 2026-09-07).** Access to documents is granted
**through collections**.

- **`collection_users`** join: `user ↔ collection` with the same ordered `role`
  vocabulary as the global one (`Roleable`), so the two are comparable.
  - `user` — search it, and draw on it in chat.
  - `operator` — + add and remove document memberships by hand.
  - `admin` — + manage its people and delete it. Deleting unfiles documents;
    it never destroys them, since they belong to the source that produced them,
    and anything that was only in that collection becomes Unsorted.
- **A missing row means no access**, not weak access. `User#role_on` returns
  `nil`, deliberately not `:user`: absence is not the weakest presence, and
  conflating them would hand every operator read access to every collection.
- Whoever creates a collection is granted `admin` on it. Otherwise an operator
  immediately can't manage what they just made, and only a system admin could
  rescue them.

**How the two axes combine — a two-band ceiling, not `min`.** The global role
caps the *kind* of thing you can do (chat / content / system); it is not another
rung on the same ladder:

- global `admin` — everything, everywhere, no grant needed.
- global `operator` — the grant exactly as written, up to and including `admin`
  **of that collection**. Managing a collection, its people included, is content
  ownership, which is what an operator is for.
- global `user` — reads at most, whatever the grant says. Chat-only means
  chat-only; a grant cannot widen it.

A numeric `min` was the original plan and is wrong: `min(operator, admin)` is
`operator`, which would mean an HR operator could not grant a colleague access
to the HR collection, leaving every access change waiting on a system admin.
That contradicts the whole point of appointing operators.
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
