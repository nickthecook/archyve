// The bundle only works as a classic script: as a module, its top-level var never
// reaches globalThis, which is where its last line looks for it.
const mermaid = await new Promise((resolve, reject) => {
  const script = document.createElement("script")
  script.src = import.meta.resolve("mermaid")
  script.onload = () => resolve(globalThis.mermaid)
  script.onerror = reject
  document.head.append(script)
})
let rendered = 0

// Mermaid 12 gives each diagram type its own default look, so flowchart repeats it.
mermaid.initialize({
  startOnLoad: false,
  theme: "base",
  look: "classic",
  themeVariables: palette(),
  flowchart: { look: "classic", curve: "step" },
})

export default async function render(pre) {
  try {
    const { svg } = await mermaid.render(`mermaid-${++rendered}`, pre.textContent)
    const figure = document.createElement("figure")
    figure.className = "diagram"
    figure.innerHTML = svg
    pre.replaceWith(figure)
  } catch (error) {
    console.error("mermaid:", error)
  }
}

// Mermaid derives its shades from hex values, so the brand tokens are read rather
// than passed as var() references.
function palette() {
  const style = getComputedStyle(document.documentElement)
  const token = (name) => style.getPropertyValue(`--${name}`).trim()

  return {
    darkMode: true,
    dropShadow: "none",
    useGradient: false,
    fontFamily: token("font-sans"),
    background: token("color-base"),
    primaryColor: token("color-ink"),
    primaryBorderColor: token("color-line-2"),
    primaryTextColor: token("color-fg"),
    secondaryColor: token("color-void"),
    tertiaryColor: token("color-base"),
    lineColor: token("color-muted"),
    textColor: token("color-fg"),
  }
}
