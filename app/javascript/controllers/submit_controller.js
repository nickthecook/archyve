import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="submit"
export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.inputTarget.addEventListener("keydown", this.handleKeyDown.bind(this))
  }

  handleKeyDown(event) {
    if (event.key === "Enter") {
      if (event.shiftKey) {
        event.preventDefault()
      } else {
        const form = this.element.closest('form')
        const submitButton = form.querySelector("input[type='submit']")
        submitButton.click()
        event.preventDefault()
      }
    }
  }
}
