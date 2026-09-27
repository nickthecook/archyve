import { Controller } from "@hotwired/stimulus"

// A <details>-backed alternative to a <select> for "draw on another source":
// each option row can show the source's name, type and location, which a
// plain <select>'s options can't lay out. Picking a row copies its value into
// the hidden input the form submits, closes the panel, and enables the submit
// button — which starts disabled because a hidden input's `required` isn't
// enforced by the browser.
export default class extends Controller {
  static targets = ["input", "label", "submit"]

  select(event) {
    const option = event.currentTarget
    const details = option.closest("details")

    this.inputTarget.value = option.dataset.value
    this.labelTarget.textContent = option.dataset.label
    this.submitTarget.disabled = false
    if (details) details.open = false
  }
}
