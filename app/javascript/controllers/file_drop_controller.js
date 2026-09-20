import { Controller } from "@hotwired/stimulus"

// Turns a dashed box into a second doorway to the form's file input. It never
// uploads anything itself: the dropped file is assigned to the input, so the
// filename display, the required validation and the submit all stay native.
export default class extends Controller {
  static targets = ["input", "zone"]
  static classes = ["idle", "active"]

  accept(event) {
    event.preventDefault()
    this.paint(false)

    const [file] = event.dataTransfer.files
    if (!file) return

    // An input's files list is only assignable from a DataTransfer.
    const transfer = new DataTransfer()
    transfer.items.add(file)
    this.inputTarget.files = transfer.files
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  activate(event) {
    event.preventDefault()
    this.paint(true)
  }

  // dragleave also fires on the way into a child, which would flicker the box.
  deactivate(event) {
    if (this.zoneTarget.contains(event.relatedTarget)) return
    this.paint(false)
  }

  browse() {
    this.inputTarget.click()
  }

  paint(active) {
    const [add, remove] = active
      ? [this.activeClasses, this.idleClasses]
      : [this.idleClasses, this.activeClasses]

    this.zoneTarget.classList.add(...add)
    this.zoneTarget.classList.remove(...remove)
  }
}
