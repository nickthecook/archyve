import { Controller } from "@hotwired/stimulus";

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
    if (event.key === "Enter" && !event.shiftKey) {
      const form = this.element.closest("form");
      const submitButton = form.querySelector("input[type='submit']");
      submitButton.click();
      event.preventDefault();
    }
  }
}
