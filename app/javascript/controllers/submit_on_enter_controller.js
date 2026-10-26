import { Controller } from "@hotwired/stimulus"

// Enter submits the textarea's form; Shift+Enter is a newline, as in the chat
// composer.
export default class extends Controller {
  submit(event) {
    // Mid-composition Enter is the IME committing a candidate, not a send.
    if (event.isComposing) return

    event.preventDefault()
    this.element.form.requestSubmit()
  }
}
