import { Controller } from "@hotwired/stimulus"

// Sends a composer with Ctrl+Enter (Cmd+Enter on Mac). Plain Enter stays a
// newline — messages are often multi-line, so sending is the deliberate act.
//
// Two things in the action descriptor are load-bearing. The modifiers live in
// the key filter rather than in here, because Stimulus drops any keydown whose
// modifier state doesn't match the filter exactly — a bare `keydown.enter`
// action never sees a Ctrl+Enter to test for. And it listens on @document so
// the shortcut works wherever the caret is: the box autofocuses on load (on
// desktop — see #connect), and a click anywhere else would otherwise silently
// disarm the shortcut.
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
    // An empty box has nothing to send. The server says the same thing with a
    // redirect and an alert; from a keystroke, doing nothing is the better
    // answer — the user hasn't typed the message yet.
    if (this.fieldTarget.value.trim() === "") return

    event.preventDefault()
    this.element.requestSubmit()
  }
}
