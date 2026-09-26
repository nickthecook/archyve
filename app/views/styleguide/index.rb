# frozen_string_literal: true

# The living style guide: every entry below renders the *real* component or the
# exact class string the app uses, so this page cannot quietly drift from the
# UI the way docs/design.md can. If something here looks wrong, the app is
# wrong. Admin-only — it is a maker's tool, not a feature.
#
# Entries are labelled "component" (a class other views render, so it is
# guaranteed truthful) or "pattern" (a class string duplicated here, which can
# drift — promote it to a component if it starts mattering).
class Views::Styleguide::Index < Views::Base
  # Literal class strings, deliberately: Tailwind scans these .rb files as text,
  # so a computed "bg-#{token}" would never be generated.
  PALETTE = [
    ["void", "bg-void", "Ground"],
    ["base", "bg-base", "Page"],
    ["ink", "bg-ink", "Raised surface"],
    ["line", "bg-line", "Structure, at rest"],
    ["line-2", "bg-line-2", "Structure, on hover"],
    ["fg", "bg-fg", "Primary text"],
    ["muted", "bg-muted", "Body / secondary text"],
    ["faint", "bg-faint", "Supporting detail"],
    ["accent", "bg-accent", "Interaction & consequence"],
    ["accent-dim", "bg-accent-dim", "Accent, pressed"]
  ].freeze

  BUTTONS = [
    ["Solid", "Commits something — form submits only",
     "rounded bg-accent px-3 py-2 text-sm font-medium text-void hover:bg-accent-dim transition-colors"],
    ["Outlined", "Primary, but only opens something",
     "rounded border border-accent/60 bg-accent/10 px-3 py-2 text-sm font-medium text-accent hover:bg-accent/20 hover:border-accent transition-colors"],
    ["Quiet", "Secondary actions",
     "rounded border border-line px-3 py-2 text-sm text-muted hover:text-fg hover:border-line-2 transition-colors"]
  ].freeze

  def view_template
    heading
    section("Palette", "component") { palette }
    section("Doorways", "component") { doorways }
    section("Breadcrumbs", "component") { breadcrumbs }
    section("Buttons", "pattern") { buttons }
    section("Status", "component") { statuses }
    section("Cards", "pattern") { cards }
    section("Derived & empty", "pattern") { derived }
    section("Numerals", "pattern") { numerals }
    section("Working", "component") { spinners }
  end

  private

  def page_title = "Style guide"

  def heading
    header(class: "mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Style guide" }
      p(class: "mt-1 text-sm text-muted") do
        plain "Rendered from the real components. The rules behind these choices live in "
        code(class: "font-mono text-xs text-faint") { "docs/design.md" }
        plain "; the colour values live in the Tailwind "
        code(class: "font-mono text-xs text-faint") { "@theme" }
        plain " block."
      end
    end
  end

  def section(title, kind)
    div(class: "mb-10") do
      div(class: "mb-3 flex items-baseline gap-2") do
        h2(class: "text-xs font-semibold uppercase tracking-[0.18em] text-muted") { title }
        span(class: "font-mono text-[0.65rem] text-faint") { kind }
      end
      yield
    end
  end

  def palette
    div(class: "grid grid-cols-2 gap-2 sm:grid-cols-3") do
      PALETTE.each do |name, swatch, role|
        div(class: "flex items-center gap-3 rounded-lg border border-line bg-ink/40 p-3") do
          span(class: "h-8 w-8 shrink-0 rounded border border-line-2 #{swatch}")
          div(class: "min-w-0") do
            p(class: "font-mono text-xs text-fg") { name }
            p(class: "truncate text-[0.7rem] text-faint") { role }
          end
        end
      end
    end
  end

  # The real component, so the rail, tile and chevron can never drift from the
  # ones on the collections page.
  def doorways
    div(class: "flex flex-col gap-3") do
      render Views::Doorway.new(
        href: styleguide_path, title: "With everything",
        description: "Description, count, chevron — the full row.", meta: "2 sources"
      ) { sample_icon }
      render Views::Doorway.new(href: styleguide_path, title: "Title only") { sample_icon }
    end
  end

  # The counterpart to a doorway: a doorway leads across, a trail leads back up.
  # The last crumb is the page itself and doesn't link.
  def breadcrumbs
    div(class: "flex flex-col gap-1") do
      breadcrumb(["Collections", styleguide_path], "Archyve Design")
      breadcrumb(["Settings", styleguide_path], ["Inference", styleguide_path], ["tensor", styleguide_path], "Edit")
    end
  end

  def buttons
    div(class: "flex flex-wrap items-center gap-3") do
      BUTTONS.each do |label, role, classes|
        div(class: "flex flex-col gap-1.5") do
          button(type: "button", class: classes) { label }
          span(class: "text-[0.7rem] text-faint") { role }
        end
      end
    end
  end

  def statuses
    div(class: "flex flex-wrap items-center gap-2") do
      Views::Documents::StatusBadge::COLORS.each_key do |status|
        render Views::Documents::StatusBadge.new(status:)
      end
    end
  end

  def cards
    div(class: "grid grid-cols-1 gap-3 sm:grid-cols-2") do
      2.times do |i|
        div(class: "rounded-lg border border-line bg-ink/40 p-4 hover:border-line-2 transition-colors") do
          p(class: "text-sm font-medium text-fg") { "Card #{i + 1}" }
          p(class: "mt-1 text-xs text-faint") { "One costume for every repeated item on a page." }
        end
      end
    end
  end

  def derived
    div(class: "rounded-lg border border-dashed border-line px-4 py-8 text-center") do
      p(class: "text-sm text-muted") { "Dashed means \"not a real thing\"" }
      p(class: "mt-1 text-xs text-faint") { "Derived views, empty states, and no-match placeholders." }
    end
  end

  def numerals
    div(class: "rounded-lg border border-line bg-ink/40 p-4") do
      [1234, 88, 7].each do |n|
        div(class: "flex items-center justify-between border-b border-line/60 py-1 last:border-0") do
          span(class: "text-sm text-muted") { "Row" }
          span(class: "font-mono tabular-nums text-sm text-fg") { n.to_s }
        end
      end
    end
  end

  # Three sizes at once, because the beat reads differently small: at 12px the
  # flip is most of what you see, at 24px the travel is.
  def spinners
    div(class: "rounded-lg border border-line bg-ink/40 p-4") do
      div(class: "flex flex-wrap items-center gap-x-6 gap-y-3") do
        [12, 15, 24].each do |size|
          div(class: "flex items-center gap-2.5") do
            span(class: "grid h-7 w-7 place-items-center rounded bg-accent/10 text-accent") do
              render Views::Spinner.new(size:)
            end
            span(class: "font-mono text-[0.65rem] text-faint tabular-nums") { "#{size}px" }
          end
        end
        span(class: "ml-2 flex items-center gap-2 text-faint") do
          render Views::Spinner.new(size: 15)
          span(class: "text-xs") { "inherits colour" }
        end
      end
      p(class: "mt-4 text-xs text-faint") do
        plain "#{Views::Spinner::DEGREES}° a beat, #{Views::Spinner::BEAT_MS}ms a beat. "
        plain "Reduced motion holds it still and breathes instead."
      end
    end
  end

  def sample_icon
    svg(width: "18", height: "18", viewbox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "1.6", aria_hidden: "true") do |s|
      s.path(d: "M3 8a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z")
    end
  end
end
