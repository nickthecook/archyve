import { Controller } from "@hotwired/stimulus"

// Grows a textarea to fit its content. Attaches directly to the textarea,
// unlike the chat composer's version, which tracks a separate field target
// inside a larger element.
export default class extends Controller {
  connect() {
    this.resize()
  }

  // Clearing the height before measuring is what lets the box shrink again;
  // scrollHeight never reports less than the current height.
  resize() {
    // A hidden field measures 0, which would pin it there once it is shown.
    if (this.element.offsetParent === null) return

    // The `rows` attribute is the floor: an empty box keeps the height the
    // markup asked for rather than collapsing to a single line.
    this.minHeight ??= this.element.clientHeight
    this.element.style.height = "auto"
    this.element.style.height = `${Math.max(this.element.scrollHeight, this.minHeight)}px`
  }
}
