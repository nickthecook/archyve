import { Controller } from "@hotwired/stimulus"

// The "reduce motion" switch. Persists the choice to a year-long cookie so the
// server can add html.reduce-motion before first paint (no flash), toggles that
// class live, and announces the change (motion:toggled) so running animation
// controllers — e.g. corridor — can settle immediately without a reload.
export default class extends Controller {
  static targets = ["checkbox"]

  toggle() {
    const reduce = this.checkboxTarget.checked
    document.cookie = `reduce_motion=${reduce ? "1" : "0"}; path=/; max-age=31536000; samesite=lax`
    document.documentElement.classList.toggle("reduce-motion", reduce)
    this.dispatch("toggled", { detail: { reduce } })
  }
}
