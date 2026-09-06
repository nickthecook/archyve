import { Controller } from "@hotwired/stimulus"

// Briefly flash the chunk a search result deep-linked to. Turbo scrolls to the
// URL fragment on its own, but its pushState navigation never triggers the CSS
// :target pseudo-class, so the cue is done here. WAAPI keeps it self-contained —
// no stylesheet, and it leaves no lingering inline styles.
export default class extends Controller {
  connect() {
    const id = window.location.hash.slice(1)
    if (!id) return

    const target = this.element.querySelector(`#${CSS.escape(id)}`)
    if (!target) return

    const reduced =
      matchMedia("(prefers-reduced-motion: reduce)").matches ||
      document.documentElement.classList.contains("reduce-motion")
    if (reduced) return

    // Brass ring + wash that fades out — enough to pick the chunk out of a wall
    // of similar cards without becoming decoration.
    target.animate(
      [
        { boxShadow: "0 0 0 1px rgba(230, 180, 85, 0.9)", backgroundColor: "rgba(230, 180, 85, 0.08)" },
        { boxShadow: "0 0 0 1px rgba(230, 180, 85, 0)", backgroundColor: "rgba(230, 180, 85, 0)" }
      ],
      { duration: 1600, easing: "ease-out" }
    )
  }
}
