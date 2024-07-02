import { Controller } from "@hotwired/stimulus";

function pasteIntoInput(el, text) {
  el.focus();
  if (
    typeof el.selectionStart == "number" &&
    typeof el.selectionEnd == "number"
  ) {
    var val = el.value;
    var selStart = el.selectionStart;
    el.value = val.slice(0, selStart) + text + val.slice(el.selectionEnd);
    el.selectionEnd = el.selectionStart = selStart + text.length;
  } else if (typeof document.selection != "undefined") {
    var textRange = document.selection.createRange();
    textRange.text = text;
    textRange.collapse(false);
    textRange.select();
  }
}

export default class extends Controller {
  static targets = ["input"];

  connect() {
    console.log("auto-grow-text-area connected");
    this.inputTarget.style.resize = "none";
    this.inputTarget.style.minHeight = `${this.inputTarget.scrollHeight}px`;
    this.inputTarget.style.overflow = "hidden";

    this.inputTarget.addEventListener("keydown", this.handleKeyDown.bind(this));
  }

  resize(event) {
    event.target.style.height = "5px";
    event.target.style.height = `${event.target.scrollHeight}px`;
  }

  handleKeyDown(event) {
    if (event.key === "Enter") {
      console.log(1);
      if (event.shiftKey) {
        console.log(2);
        pasteIntoInput(this, "\n");
        event.preventDefault();
      } else {
        const form = this.element.closest("form");
        const submitButton = form.querySelector("input[type='submit']");
        submitButton.click();
        event.preventDefault();
      }
    }
  }
}
