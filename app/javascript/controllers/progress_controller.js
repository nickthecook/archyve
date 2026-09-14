import { Controller } from "@hotwired/stimulus"

// User state a swap would throw away. Checked boxes and moved dropdowns are
// asked about separately; hidden and file inputs hold nothing of the user's.
const TEXTUAL = "input[type=text], input[type=search], input:not([type]), textarea"

const some = (element, selector, predicate) => [...element.querySelectorAll(selector)].some(predicate)

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
    // Ask only for what something on the page can actually take: a region nobody
    // can see, or one being worked in, is skipped — and if that accounts for all
    // of them, there is nothing to ask the server for. This is what keeps a
    // region behind a closed disclosure down to a timer tick and no request.
    const companions = this.alsoValue.map((id) => document.getElementById(id))
    const targets = [...companions, this.element].filter((el) => el && this.swappable(el))
    if (targets.length === 0) return

    const response = await fetch(window.location.href, { headers: { Accept: "text/html" } })
    if (!response.ok) return

    const page = new DOMParser().parseFromString(await response.text(), "text/html")

    // this.element sorts last: replacing it takes this controller with it.
    for (const stale of targets) {
      const fresh = page.getElementById(stale.id)
      if (fresh) stale.replaceWith(fresh)
    }
  }

  // Worth swapping and safe to swap.
  swappable(element) {
    return this.visible(element) && !this.busy(element)
  }

  // The case this exists for is a region inside a closed disclosure. That gets
  // asked directly rather than left to checkVisibility, which reports on CSS
  // the page set — not on a <details> the browser is collapsing itself.
  visible(element) {
    if (element.closest("details:not([open])")) return false

    return element.checkVisibility?.() ?? true
  }

  // Text typed in, a box ticked, a dropdown moved off the default it rendered
  // with, or the caret sitting somewhere inside.
  busy(element) {
    if (element.contains(document.activeElement)) return true
    if (element.querySelector("input:checked")) return true
    if (some(element, TEXTUAL, (field) => field.value !== "")) return true

    return some(element, "select", (field) => [...field.options].some((o) => o.selected !== o.defaultSelected))
  }
}
