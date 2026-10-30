# Design

How Archyve's UI is put together, and why. This file records **decisions and
rules**, not values — the palette, fonts and spacing scale live in the `@theme`
block of `app/assets/tailwind/application.css`, and prose copies of hex codes
drift. If you want to know what `accent` *is*, read the CSS. This is what it
*means*.

**`/styleguide`** (admin-only) renders these rules from the real components —
palette, doorways, the button ladder, status badges. Prose drifts; that page
can't. Check a change there before trusting this file.

Tailwind scans Phlex views via `@source "../../../app/**/*.rb"`. All views are
Phlex classes under `app/views/`; there is no ERB.

## The palette carries meaning

| Token | Role |
|---|---|
| `void`, `base`, `ink` | Ground, receding to raised. `ink/40` is a resting surface, `ink/60` a raised one. |
| `line`, `line-2` | Structure. `line` at rest, `line-2` on hover — borders brighten, they don't change hue. |
| `fg`, `muted`, `faint` | Text, in descending importance. Body copy is `muted`; supporting detail is `faint`. |
| `accent`, `accent-dim` | Brass. Interaction and consequence — never decoration. |

**The accent budget is the whole game.** Brass reads as "this matters" only
while it stays rare. One accent rail per zone, one solid accent button per
surface. If a page has three brass elements competing, it has none.

## Zones: ways out, then the page

Pages are split by a single rule — `Views::Rule`, a `border-line-2` hairline
with its own vertical space. It is deliberately a step brighter than `line`,
which is what cards and inputs outline in:

- **Above the rule** — links that *leave* this page: section doorways, global
  search. This is what Archyve has instead of a sidebar.
- **Below the rule** — this page's own content and the controls that act on it.

The rule means exactly that one thing. Don't add a second one inside the content
zone to separate two controls that look alike — fix those with spacing, or by
making them look less alike. See `app/views/collections/index.rb`.

### Doorway rows

A doorway is a link out of the page, and it deliberately breaks the card
vocabulary below it:

```ruby
a(href: …, class: "group mb-8 flex items-center gap-4 rounded-lg border border-line " \
                  "border-l-2 border-l-accent bg-ink/60 px-5 py-4 hover:bg-ink transition-colors")
```

with an accent icon tile (`grid h-9 w-9 place-items-center rounded bg-accent/10
text-accent`) and a trailing chevron that nudges `group-hover:translate-x-0.5`.

Hover changes the **background**, not the border: `hover:border-line-2` sets all
four border colours and would stomp the accent rail.

A doorway is *singular* — one link out, sitting above the page's content. When
the links out **are** the content (a menu page like `Views::Sources::ChooseType`,
where every row leads elsewhere), they stay cards. A rail on every row is a rail
on none.

Doorways are for pages that stand on their own and offer a way *across*
(`Views::Settings::Index`, `Views::Collections::Index`).

### Breadcrumbs

A page you came *down* into — one chat, one document, one person — opens with
its trail instead, and no rule under it:

```ruby
breadcrumb(["Settings", settings_path], ["Inference", settings_inference_servers_path], @server.name)
```

`Views::Base#breadcrumb` takes `[label, href]` crumbs and a bare label for the
page you are on; the last crumb never links, so no page offers a way back to
itself. A section root — anything reachable from the top bar — has no trail.

The trail is the whole way down, not just the parent: it is what the page has
instead of a sidebar, so a reader can see where they are as well as get back.
Where a page has no fixed parent it says where you came *from* instead — see
`DocumentsController#back_link`, where a document opened from a chat citation
leads back to that chat.

## One box costume

Cards — the repeated content items of a page — all wear the same thing:

```
rounded-lg border border-line bg-ink/40 hover:border-line-2 transition-colors
```

When everything on a page wears it, the page reads as a mishmash of boxes with
no hierarchy. **Weight comes from being unlike the cards, not from being a
louder card.** Differentiate by kind: a rail, a different fill, no box at all.

Derived or empty things — Unsorted, empty states, "no matches" — use
`border-dashed border-line` and recessive text. Dashed means "not a real thing,"
and it's used consistently for that.

## The accent ladder for buttons

Before making a button solid, ask whether clicking it *commits* anything.

| Weight | Classes | Use |
|---|---|---|
| Solid | `bg-accent text-void hover:bg-accent-dim` | The action that commits — form submits. |
| Outlined | `border border-accent/60 bg-accent/10 text-accent hover:bg-accent/20 hover:border-accent` | Primary controls that only *open* something. Add `group-open:` for disclosures. |
| Quiet | `border border-line text-muted hover:text-fg hover:border-line-2` | Secondary actions. |
| Danger | `border border-red-400/40 text-red-300 hover:bg-red-400/10` | Destroys something. Never solid, always paired with a `turbo_confirm` — the cost belongs in the confirmation, not beside the button. |

Give outlined buttons a border even where the design doesn't demand one: a
borderless button sits 2px shorter than bordered siblings in a flex row.

Don't put `cursor-pointer` on a button. Tailwind v4 resets buttons to
`cursor: default`, so the base layer in `app/assets/tailwind/application.css`
hands the pointer back to every enabled `button` / `[role=button]` at once —
scattered utilities get missed, and a button that doesn't change the cursor
reads as one that doesn't do anything. Things that *aren't* buttons but are
clickable — `summary`, a `label` wrapping a checkbox — still say it themselves.

## Status has a fixed vocabulary

`pending` / `processing` / `processed` / `failed` / `removed` are the ingestion
statuses, and they always look the same: `Views::Documents::StatusBadge#COLORS`
is the source of truth (tinted background at 15%, matching text). The segmented
meter in `Views::Collections::Index#METER` uses solid fills of the same
vocabulary. Add a status in both places or not at all.

## Type and numerals

- Face is `font-sans` (currently IBM Plex Sans, self-hosted; see
  `app/assets/stylesheets/fonts.css`). No CDN, ever.
- Counts, durations and anything scannable in a column use
  `font-mono tabular-nums` so digits don't jitter between rows.
- Page headings are `text-2xl font-semibold tracking-tight`, with a `text-sm
  text-muted` sentence underneath saying what the page is for.
- The ARCHYVE wordmark is a treatment, not a face: caps tracked out `0.42em`.

## Motion

Decorative motion must never make the user wait to interact. Hover nudges,
pulses and the landing corridor are all ambient — nothing gates a click on an
animation finishing. Reduced-motion preferences turn ambient motion off.

## Narrow viewports

The app is one `max-w-3xl` column, which is most of the way to working on a
phone already. The rules that keep it there:

- **Mobile-first.** The bare class is the narrow behaviour; `sm:` restores the
  desktop look. Write both out in full — Tailwind scans these files as text, so
  an interpolated class name silently doesn't exist.
- **Still no sidebar, and no drawer.** The top bar wraps to a second line rather
  than collapsing into a hamburger. A menu you have to open to discover is worse
  than two lines of links you can see. The one exception is `/help`: a manual
  wants its contents beside it, and the different shape says you are in it. On a
  phone the contents collapse into a `<details>` at the top of the page.
- **Nothing scrolls sideways except content that should.** A wide comparison
  table is allowed to scroll inside itself; a page is not. If something overflows,
  the fix is wrapping or dropping a part, not a page-wide scroll.
- **What scrolls has to look like it scrolls.** Phone scrollbars are overlay and
  vanish when idle, so a clipped table reads as a broken layout. Scroll
  containers get a thin persistent bar and `overscroll-behavior-x: contain`.
- **Text you didn't write gets `break-words`.** Anything from a model or a
  document — snippets, queries, reasoning, answers — can contain a token with no
  break opportunity, and one is enough to push the page sideways.
- **Chrome gives way before content.** When the bar has to lose something, it
  loses the parts that repeat elsewhere: the account email is in the menu it
  opens, so the bar shows an initial instead.

## Adding a page


1. Heading: title + one `text-muted` sentence.
2. Doorway rows for anything that leaves the page.
3. The `hr`.
4. The page's content, using the card costume for repeated items.
5. Derived/empty states dashed and quiet.
6. At most one solid brass button, and only if it commits.

## Long lists page by cursor

Any list long enough to page uses `Page`, over `activerecord_cursor_paginate`,
with `Views::Pager` for the buttons below it. These lists are written to while
they are read, and an offset window shifts under the reader: a row arrives, and
the next screen shows one it has already shown. A cursor names a row instead, so
the screen after it is the same screen whatever happened meanwhile. The cost is
that there are no page numbers and no total, which a log doesn't miss.

`Page` defaults to newest first; a list people read by name passes
`order: { title: :asc }` and wants a `(title, id)` index to match. The gem was
chosen over Pagy and Kaminari because it renders nothing — pagination markup
from a gem is ERB, and this app has none.

## Admin pages come from a generator

A model's admin screens are generated rather than written:

```
bin/rails generate admin:resource ApiCall
```

That emits a controller, a Phlex index and show view, a request spec, and a
route inside `namespace :settings` — ordinary pages you own and edit afterwards.

They hang off **the Admin page**, `/settings/admin`: one card per model, and
the trail every generated page leads back through. Settings reaches it by a
doorway above the rule rather than a row of its menu, because browsing stored
records is a different job from changing what Archyve does — which is also why
it is the one accent rail on that page. The menu row itself is
`Views::MenuCard`, shared with the Settings menu.
The generator never runs over the same model twice, so what keeps the pages
looking alike as models are added is not it but the kit they render:
`Views::Admin::Heading`, `Section`, `Table`, `FieldList`, `Field`, `Json`,
`Filters`, `Facet` and `Empty`, with `Views::Admin::Formats` for how a value
reads (`ago`, `yes_no`, `count`, `text`, and `—` for nothing).

Which filters a list offers is the resource's own business, not the kit's: see
`ApiCalls::Listing`, where a facet is one line naming the param, what it offers
and how it narrows. Filtering is a GET form, so a filtered list stays a URL.

Fields are guessed from the table's columns, which is a starting point rather
than an answer: labels and the index blurb are written for a reader, and the
generator only knows what the columns are called.

A `Views::Admin::Field` block either returns a String, which is printed, or
renders its own markup and returns anything else — a badge or a link can't be a
String. `app/views/settings/api_calls/` is a generated resource that was then
customized: its own outcome badge, and fields grouped into sections.
