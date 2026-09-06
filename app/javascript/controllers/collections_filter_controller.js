import { Controller } from "@hotwired/stimulus"

// Narrows the collection list as you type. Pure client-side list-narrowing (a
// "filter"), distinct from search "scope" — it never touches what a query
// targets, only which cards are visible. Matches against each card's
// data-name (lowercased server-side).
export default class extends Controller {
  static targets = ["query", "item", "empty"]

  filter() {
    const term = this.queryTarget.value.trim().toLowerCase()
    let visible = 0

    this.itemTargets.forEach((item) => {
      const match = term === "" || item.dataset.name.includes(term)
      item.hidden = !match
      if (match) visible++
    })

    if (this.hasEmptyTarget) this.emptyTarget.hidden = visible > 0
  }
}
