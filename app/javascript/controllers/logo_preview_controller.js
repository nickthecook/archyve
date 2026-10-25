import { Controller } from "@hotwired/stimulus"

// Shows a picked logo before it's saved. The file only uploads with the form,
// so the rest of the site keeps the old one until Save.
export default class extends Controller {
  static targets = ["input", "frame", "image", "remove"]

  connect() {
    this.saved = this.imageTarget.getAttribute("src")
  }

  disconnect() {
    this.revoke()
  }

  // Cancelling the picker can empty the input, and then the saved logo is what
  // Save would keep.
  show() {
    const [file] = this.inputTarget.files
    this.revoke()

    if (file) {
      this.url = URL.createObjectURL(file)
      this.display(this.url)
      if (this.hasRemoveTarget) this.removeTarget.checked = false
    } else {
      this.display(this.saved)
    }
  }

  display(src) {
    if (src) this.imageTarget.src = src
    this.frameTarget.hidden = !src
  }

  revoke() {
    if (this.url) URL.revokeObjectURL(this.url)
    this.url = null
  }
}
