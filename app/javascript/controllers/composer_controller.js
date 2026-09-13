import { Controller } from "@hotwired/stimulus"

// Sends a composer with Ctrl+Enter (Cmd+Enter on Mac). Plain Enter stays a
// newline — messages are often multi-line, so sending is the deliberate act.
//
// Two things in the action descriptor are load-bearing. The modifiers live in
// the key filter rather than in here, because Stimulus drops any keydown whose
// modifier state doesn't match the filter exactly — a bare `keydown.enter`
// action never sees a Ctrl+Enter to test for. And it listens on @document so
// the shortcut works wherever the caret is: the box only autofocuses on load,
// and a click anywhere else would otherwise silently disarm the shortcut.
export default class extends Controller {
  static targets = ["field"]

  submit(event) {
    // An empty box has nothing to send. The server says the same thing with a
    // redirect and an alert; from a keystroke, doing nothing is the better
    // answer — the user hasn't typed the message yet.
    if (this.fieldTarget.value.trim() === "") return

    event.preventDefault()
    this.element.requestSubmit()
  }
}
