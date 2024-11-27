import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="toggle-visibility"
export default class extends Controller {
  toggle(event) {
    // get all child divs
    const elements = this.element.getElementsByTagName("div");
    const parent = this.element;

    for (var element of elements) {
      // if the div has the 'toggle-visiblity' class, toggle the 'hidden' class
      if (
        typeof element.classList !== "undefined" &&
        element.classList.contains("toggle-visibility") &&
        element.parentElement === parent
      ) {
        element.classList.toggle("hidden");
      }
    }
  }
}
