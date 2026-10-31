import { Controller } from "@hotwired/stimulus"

// Turns fenced code blocks into what their language describes. Each renderer
// loads only on a page that has a block for it.
const renderers = {
  mermaid: () => import("fences/mermaid"),
}

export default class extends Controller {
  async connect() {
    for (const [lang, load] of Object.entries(renderers)) {
      const blocks = [...this.element.querySelectorAll(`pre[lang="${lang}"]`)]
      if (blocks.length === 0) continue

      const { default: render } = await load()
      for (const block of blocks) await render(block)
    }
  }
}
