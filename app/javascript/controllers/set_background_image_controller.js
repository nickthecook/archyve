import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="set-background-image"
export default class extends Controller {
  connect() {
    document.getElementById('background').style.backgroundImage = `url(${this.data.get('target')})`
  }
}
