import { Controller } from "@hotwired/stimulus"

// Shows and hides a panel that can't sit inside its own toggle, the way a
// <details> body must.
export default class extends Controller {
  static targets = ["toggle", "panel", "field"]

  toggle() {
    const opening = this.panelTarget.hidden
    this.panelTarget.hidden = !opening
    this.toggleTarget.setAttribute("aria-expanded", opening)
    if (opening && this.hasFieldTarget) this.fieldTarget.focus()
  }
}
