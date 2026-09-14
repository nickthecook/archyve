import { Controller } from "@hotwired/stimulus"

// Anything inside the region has user state a swap would throw away. Checked
// boxes are asked separately (:checked), selects keep their value across a swap.
const TEXTUAL = "input[type=text], input[type=search], input:not([type]), textarea"

// Keeps a region fresh while a background job is still moving: poll the page and
// swap the region in from the response, stopping once the region it swapped in
// reports terminal — including when the swap came from a Turbo Stream broadcast
// rather than our own poll.
//
// On a document's show page this is a safety net: the broadcast delivers the
// instant update, and the poll only covers the one that fires before this page's
// ActionCable subscription exists (there is no replay). On list pages — an index,
// Unsorted, a collection — it is the whole mechanism: nothing broadcasts to them,
// and per-document broadcasts would be thousands of messages to nudge a row of
// badges, which is the trade Views::Sources::LastScan already explains.
export default class extends Controller {
  static values = {
    terminal: Boolean,
    interval: { type: Number, default: 2500 },
    // Ids of other regions that go stale with this one — a header count, a
    // status meter — swapped from the same response rather than their own poll.
    also: { type: Array, default: [] },
  }

  connect() {
    if (this.terminalValue) return
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async refresh() {
    // Never yank the DOM out from under someone working in it: the swap would
    // drop their checkbox selections and reset an applied filter. Skip the tick
    // entirely, fetch included — the next one lands once they're done.
    if (this.busy) return

    const response = await fetch(window.location.href, { headers: { Accept: "text/html" } })
    if (!response.ok) return

    const page = new DOMParser().parseFromString(await response.text(), "text/html")

    // Companions first: replacing this.element takes this controller with it.
    for (const id of this.alsoValue) {
      const incoming = page.getElementById(id)
      const stale = document.getElementById(id)
      if (incoming && stale) stale.replaceWith(incoming)
    }

    const fresh = page.getElementById(this.element.id)
    if (fresh) this.element.replaceWith(fresh)
  }

  // Text typed in, a box ticked, a dropdown moved off the default it rendered
  // with, or the caret sitting somewhere inside.
  get busy() {
    if (this.element.contains(document.activeElement)) return true
    if (this.element.querySelector("input:checked")) return true
    if (this.some(TEXTUAL, (field) => field.value !== "")) return true

    return this.some("select", (field) => [...field.options].some((o) => o.selected !== o.defaultSelected))
  }

  some(selector, predicate) {
    return [...this.element.querySelectorAll(selector)].some(predicate)
  }
}
