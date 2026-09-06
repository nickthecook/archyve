import { Controller } from "@hotwired/stimulus"

// Safety net for live document status. Turbo Streams deliver instant updates, but
// a broadcast that fires before this page's ActionCable subscription is
// established is lost (no replay). So while the document isn't in a terminal
// state, poll the server and swap in the fresh detail region. Stops itself once
// the replaced element reports terminal — including when the swap comes from a
// Turbo Stream broadcast rather than our own poll.
export default class extends Controller {
  static values = {
    terminal: Boolean,
    interval: { type: Number, default: 2500 },
  }

  connect() {
    if (this.terminalValue) return
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async refresh() {
    const response = await fetch(window.location.href, { headers: { Accept: "text/html" } })
    if (!response.ok) return

    const html = await response.text()
    const fresh = new DOMParser().parseFromString(html, "text/html").getElementById(this.element.id)
    if (fresh) this.element.replaceWith(fresh)
  }
}
