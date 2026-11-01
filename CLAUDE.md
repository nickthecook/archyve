# Archyve 2

A RAG archive: documents arrive from **sources**, get processed into chunks and
embeddings, and are grouped into **collections** people can search and chat over.

- **Architecture & decisions** — `docs/architecture.md` (stack, ingestion, access
  control, provider strategy). Read before changing how data flows.
- **Design rules** — `docs/design.md` (zones, box vocabulary, accent ladder).
  Read before touching a view.
- **Open work** — `docs/todo.md`.
- **Living style guide** — `/styleguide` in the running app (admin-only),
  rendering the real components.

## Commands

Everything runs through [ops](https://github.com/nickthecook/crops) (`ops.yml`):

| Command | Does |
|---|---|
| `ops server` (`ops s`) | `bin/dev` — Rails + Tailwind watcher |
| `ops test` (`ops t`) | **The** way to run specs |
| `ops lint` / `ops lint-fix` | Rubocop |
| `ops rails …` / `ops console` | Rails CLI with secrets loaded |
| `ops up` / `ops down` | Docker deps (Postgres/pgvector) in `deps/` |

**Never run specs as `ops exec bundle exec rspec`.** `ops exec` carries
`RAILS_ENV=development`, so the suite hits the development stack and every
request spec fails with a blanket 403 — an invocation error that looks like a
broken app. `ops test` sets `RAILS_ENV=test` itself.

## Views are Phlex, not ERB

There is no ERB in this app; `ApplicationController` sets `layout false` and
controllers render view objects directly:

```ruby
render Views::Collections::Index.new(rows: @rows, …)
```

- **`Views::Base`** — full pages. Wraps itself in `Views::Layout`; a view defines
  content plus optional `#page_title` / `#contained?`.
- **`Components::Base`** — fragments (badges, panels, broadcast targets). Renders
  bare. Rails helpers come from `phlex-rails` adapters registered here, not the
  deprecated `helpers` proxy.
- Tailwind scans these `.rb` files via `@source` in
  `app/assets/tailwind/application.css`; brand tokens live in its `@theme` block
  and are the single source of truth for colour.

## Access control

Two concerns: `Authentication` ("is anyone there?") and `Authorization` ("are
they allowed?"). Controllers gate with `require_role :curator` (a *minimum* —
roles are ordered). Per-collection and per-source grants combine with the global
role as a ceiling, never above it.

Views use `may?` / `may_on?` to hide affordances — **hiding a link is not access
control**. The controller must enforce the same rule; both are required.

## Domain vocabulary

- A **membership** joins a document to a collection and remembers *how* it got
  there: source-fed or manual. Feed-wins, upgrade-only; users may only edit
  manual rows. Removed memberships are tombstones, not deletions — "current
  contents" always means *active* memberships.
- **Unsorted** is a derived view (documents in no collection), not a collection.
- **Sources** live with the content they produce, not under Settings. Settings is
  administration.

## Specs

RSpec, mostly request specs — they exercise real sign-in via
`spec/support/authentication.rb`, which signs in a curator before each example
(`unauthenticated: true` opts out). Prefer contexts for input variation over flat
examples.

## Working agreements

- **Never commit, branch, or switch branches unasked.** Leave changes in the
  working tree for review.
- **Comment sparingly.** See the rules below. Do not match the density of the
  existing code — much of it is over-commented, and matching it is how it got
  that way.
- Throwaway probe scripts go in Ruby, not Python; promote reusable ones to
  `script/`.

## Comments

Rails is designed so that most classes need none, and most classes here should
have none.

1. **The code should be self-explanatory ~90% of the time.** This is Ruby on
   Rails; lean on the framework's vocabulary rather than narrating it.
2. **A comment explains *why*, never *what*** — unless a block is genuinely
   obtuse, in which case prefer fixing the block.
3. **Anything covered in `docs/architecture.md`, `docs/design.md` or a README
   does not get repeated inline.** Point at it instead.
4. **More comment lines than code lines in a file means you got it wrong.**

Two habits that cause most of the damage:

- **Arguing with alternatives you rejected.** Nobody needs to know what the code
  doesn't do. That's conversation, not documentation.
- **Commenting instead of refactoring.** A comment is often a smell: the fix is
  usually a better method name, or extracting a method so its name carries the
  intention.

Before writing a comment, check whether a name or a line in the architecture doc
does the job. Worth keeping: an ordering that breaks silently if swapped, a
surprising behaviour a caller would otherwise trip on, a consequence not visible
from the code.
