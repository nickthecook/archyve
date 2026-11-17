import { Controller } from "@hotwired/stimulus"

const NEXT = { system: "light", light: "dark", dark: "system" }

// See Views::ThemeToggle. Turbo keeps <html> across visits, so the attribute set
// here holds until the next full load, when the server sets it from the cookie.
export default class extends Controller {
  static values = { choice: String }

  cycle() {
    const choice = NEXT[this.choiceValue] ?? "system"
    this.choiceValue = choice
    document.cookie = `theme=${choice}; path=/; max-age=31536000; samesite=lax`

    const root = document.documentElement
    if (choice === "system") delete root.dataset.theme
    else root.dataset.theme = choice

    this.element.title = `Theme: ${choice}`
    this.element.setAttribute("aria-label", `Theme: ${choice}`)
  }
}
