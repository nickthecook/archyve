import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="toggle-visibility"
export default class extends Controller {
  toggle(event) {
    const parent = this.element;
    const targetElement = findTargetElement(
      this.element.dataset.toggleElementId
    );

    if (targetElement === undefined) {
      toggleChildElements(parent);
    } else {
      targetElement.classList.toggle("hidden");
    }
  }
}

function findTargetElement(targetId) {
  if (targetId !== undefined) {
    return document.getElementById(targetId);
  }
}

function toggleChildElements(parent) {
  const children = parent.getElementsByTagName("div");

  for (var element of children) {
    if (
      typeof element.classList !== "undefined" &&
      element.classList.contains("toggle-visibility") &&
      element.parentElement === parent
    ) {
      element.classList.toggle("hidden");
    }
  }
}
