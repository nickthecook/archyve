import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="sidebar"
export default class extends Controller {
  toggle(event) {
    const sidebar = document.getElementById("sidebar");
    sidebar.classList.toggle("hidden");
  }
}
