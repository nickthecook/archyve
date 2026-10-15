import { Controller } from "@hotwired/stimulus"

// Enter sends; Shift+Enter is a newline. The Enter binding sits on the field
// rather than @document so a stray Enter elsewhere on the page can't submit,
// and Stimulus matches modifier state exactly, so it never sees Shift+Enter.
// Ctrl/Cmd+Enter stays bound at @document, sending from wherever the caret is.
export default class extends Controller {
  static targets = ["field"]

  connect() {
    // The `rows` attribute is the floor: an empty box keeps the height the
    // markup asked for rather than collapsing to a single line.
    this.minHeight = this.fieldTarget.clientHeight
    this.autogrow()

    // Autofocus pops the keyboard on mobile, covering about half the screen —
    // the chat list and a just-answered message both want to be seen, not
    // typed over. Below Tailwind's `sm` breakpoint, leave the field alone.
    if (!matchMedia("(max-width: 639px)").matches) this.fieldTarget.focus()
  }

  // Clearing the height before measuring is what lets the box shrink again;
  // scrollHeight never reports less than the current height.
  autogrow() {
    const field = this.fieldTarget

    field.style.height = "auto"
    field.style.height = `${Math.max(field.scrollHeight, this.minHeight)}px`
  }

  submit(event) {
    // Mid-composition Enter is the IME committing a candidate, not a send.
    if (event.isComposing) return

    event.preventDefault()

    // An empty box has nothing to send, and a swallowed Enter beats a stray
    // leading newline. The server says the same thing with a redirect.
    if (this.fieldTarget.value.trim() === "") return

    this.element.requestSubmit()
  }
}
