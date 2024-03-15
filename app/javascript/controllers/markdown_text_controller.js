import { Controller } from "@hotwired/stimulus";
import { marked } from "marked";
import hljs from "highlight.js";
// import { HighlightJS } from "highlight.js"

// Connects to data-controller="markdown-text"
export default class extends Controller {
  static values = { updated: String }

  updatedValueChanged() {
    const markdownText = this.element.innerText || ""
    const html = marked(markdownText, {breaks: true})
    this.element.innerHTML = html
    this.element.querySelectorAll("pre").forEach((block) => {
      hljs.highlightElement(block)
    })
  }
}
