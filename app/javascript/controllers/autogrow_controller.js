import { Controller } from "@hotwired/stimulus"

// Grows a textarea to fit its content. Attaches directly to the textarea,
// unlike the chat composer's version, which tracks a separate field target
// inside a larger element.
export default class extends Controller {
  connect() {
    // The `rows` attribute is the floor: an empty box keeps the height the
    // markup asked for rather than collapsing to a single line.
    this.minHeight = this.element.clientHeight
    this.resize()
  }

  // Clearing the height before measuring is what lets the box shrink again;
  // scrollHeight never reports less than the current height.
  resize() {
    this.element.style.height = "auto"
    this.element.style.height = `${Math.max(this.element.scrollHeight, this.minHeight)}px`
  }
}
