import { Controller } from "@hotwired/stimulus"

// The landing's signature: a triangular corridor into the archive, rings at
// geometric (perspective) depth. Focus lights the far end; the pointer shifts
// the vanishing point. One rAF loop that sleeps when nothing is moving.
//
// On load the corridor builds itself: every ring starts past the far plane (so the
// frame is empty), then they bloom out of the vanishing point one after another and
// glide outward into their resting slots.
export default class extends Controller {
  static targets = ["rings", "input"]

  INTRO = 1.6   // seconds for the load bloom: rings emerge fast, then ease into place

  connect() {
    this.NS = "http://www.w3.org/2000/svg"
    this.reduce = this.motionReduced

    const apex = [300, 44], bl = [70, 476], br = [530, 476]
    this.cx = (apex[0] + bl[0] + br[0]) / 3
    this.cy = (apex[1] + bl[1] + br[1]) / 3
    this.V = [apex, br, bl]

    this.RINGS = 16
    this.RATIO = 0.8
    this.NEAR = -1.6
    this.FAR = this.NEAR + this.RINGS

    // Start from an empty rings group. Turbo Drive caches the page snapshot with
    // our appended polygons still in it; without this, a Back navigation restores
    // that snapshot and connect() appends a *second* set — a stale ghost corridor
    // over the live one. Clearing first keeps the build idempotent.
    this.polys = []
    // Branding can turn the corridor off. The controller stays connected
    // without it: lighting the field and the keyboard lift still apply.
    if (this.hasRingsTarget) {
      this.ringsTarget.replaceChildren()
      for (let i = 0; i < this.RINGS; i++) {
        const p = document.createElementNS(this.NS, "polygon")
        this.ringsTarget.appendChild(p)
        this.polys.push({ el: p, i })
      }

      // Strip the polygons before Turbo snapshots the page, so the cache matches
      // the (empty) server-rendered rings and the Back preview never shows a ghost.
      this._beforeCache = () => this.ringsTarget.replaceChildren()
      document.addEventListener("turbo:before-cache", this._beforeCache)
    }

    this.litAmt = 0
    this.litTarget = 0
    this.kbShift = 0
    this.px = 0; this.py = 0; this.tpx = 0; this.tpy = 0
    this.running = false
    // Rings sit a whole corridor-length beyond the far plane, which renders as nothing.
    this.introLeft = this.reduce ? 0 : this.INTRO
    this.introOffset = this.reduce ? 0 : this.RINGS

    this._tick = this.tick.bind(this)
    this.render()
    if (this.reduce) return
    this.kick()
  }

  disconnect() {
    if (this.raf) cancelAnimationFrame(this.raf)
    document.removeEventListener("turbo:before-cache", this._beforeCache)
    if (this.hasRingsTarget) this.ringsTarget.replaceChildren()
    this.unwatchKeyboard()
  }

  // --- input wiring (Stimulus actions) --------------------------------------
  light() {
    this.element.classList.add("is-lit")
    this.litTarget = 1
    this.kick()
    this.watchKeyboard()
  }

  dim() {
    this.element.classList.remove("is-lit")
    this.litTarget = 0
    this.kick()
    this.unwatchKeyboard()
  }

  // The stage is a fixed, non-scrolling 100vh — mobile browsers don't shrink
  // that layout viewport for the keyboard, so there's nothing for the usual
  // "scroll the focused field into view" behaviour to act on, and the field
  // (pinned at 63.8% down) can end up under the keyboard. visualViewport
  // reports the actual visible height net of the keyboard, so nudging the
  // stage up by exactly that shortfall tracks the real keyboard on any
  // device instead of guessing a height.
  watchKeyboard() {
    if (!window.visualViewport || this._vvHandler) return
    this._vvHandler = () => this.adjustForKeyboard()
    visualViewport.addEventListener("resize", this._vvHandler)
    visualViewport.addEventListener("scroll", this._vvHandler)
    this.adjustForKeyboard()
  }

  unwatchKeyboard() {
    if (this._vvHandler) {
      visualViewport.removeEventListener("resize", this._vvHandler)
      visualViewport.removeEventListener("scroll", this._vvHandler)
      this._vvHandler = null
    }
    this.kbShift = 0
    this.element.style.transform = ""
  }

  adjustForKeyboard() {
    const vv = visualViewport
    // getBoundingClientRect() already reflects any shift from the previous
    // call, so add it back to recover the field's unshifted position —
    // otherwise each call would compound on top of the last.
    const fieldRect = this.inputTarget.closest(".ask-field").getBoundingClientRect()
    const naturalBottom = fieldRect.bottom + this.kbShift
    const visibleBottom = vv.offsetTop + vv.height
    const margin = 20

    this.kbShift = Math.max(0, naturalBottom - visibleBottom + margin)
    this.element.style.transform = this.kbShift > 0 ? `translateY(-${this.kbShift.toFixed(1)}px)` : ""
  }

  peer(event) {
    if (this.reduce || !this.hasRingsTarget) return
    const r = this.ringsTarget.getBoundingClientRect()
    // Tracked window-wide, so the pointer can range well past the rings; clamp
    // the offset so the parallax stays controlled toward the viewport edges.
    this.tpx = this.clamp((event.clientX - (r.left + r.width / 2)) / r.width, -0.6, 0.6)
    this.tpy = this.clamp((event.clientY - (r.top + r.height / 2)) / r.height, -0.6, 0.6)
    this.kick()
  }

  rest() { this.tpx = 0; this.tpy = 0; this.kick() }

  // True when either the OS setting or the site's reduce-motion cookie is on.
  get motionReduced() {
    return matchMedia("(prefers-reduced-motion: reduce)").matches ||
      document.documentElement.classList.contains("reduce-motion")
  }

  // Live response to the bottom-bar switch (motion:toggled). Turning it on
  // settles the corridor to a static frame; turning it off resumes the loop.
  motion(event) {
    this.reduce = event ? event.detail.reduce : this.motionReduced
    if (this.reduce) {
      this.introLeft = 0; this.introOffset = 0
      this.tpx = 0; this.tpy = 0; this.px = 0; this.py = 0
      this.litTarget = this.element.classList.contains("is-lit") ? 1 : 0
      this.litAmt = this.litTarget
      if (this.raf) cancelAnimationFrame(this.raf)
      this.running = false
      this.render()
    } else {
      this.kick()
    }
  }

  // --- engine ---------------------------------------------------------------
  clamp(v, a, b) { return Math.min(b, Math.max(a, v)) }
  lerp(a, b, t) { return a + (b - a) * t }

  drawRing(o) {
    let p = o.i
    while (p < this.NEAR) p += this.RINGS
    while (p >= this.FAR) p -= this.RINGS
    p += this.introOffset   // load bloom only; zero once the corridor has arrived
    const s = Math.pow(this.RATIO, p)

    const env = this.clamp((p - this.NEAR) / 1.6, 0, 1) * this.clamp((this.FAR - p) / 2.0, 0, 1)
    const sc = Math.min(s, 1)
    const baseCore = 0.9 * Math.pow(sc, 0.4)
    const litCore = Math.pow(sc, 0.15)
    const op = (baseCore + (litCore - baseCore) * this.litAmt) * env
    const warmth = Math.pow(this.clamp(1 - sc, 0, 1), 1.4) * this.litAmt

    const k = (1 - sc) * 24
    const dx = this.px * k, dy = this.py * k
    const pts = this.V.map(([x, y]) =>
      `${(this.cx + (x - this.cx) * s + dx).toFixed(1)},${(this.cy + (y - this.cy) * s + dy).toFixed(1)}`).join(" ")

    o.el.setAttribute("points", pts)
    // Inline style rather than the attribute, so the theme can retint the rings live.
    o.el.style.stroke = `color-mix(in srgb, var(--corridor-lit) ${(warmth * 100).toFixed(1)}%, var(--corridor-ring))`
    o.el.setAttribute("stroke-width", this.clamp(4.4 * Math.pow(Math.min(s, 1.3), 0.8), 0.25, 5.5).toFixed(2))
    o.el.setAttribute("opacity", op.toFixed(3))
  }

  render() { for (const o of this.polys) this.drawRing(o) }

  tick() {
    const now = performance.now()
    const dt = Math.min((now - this.lastT) / 1000, 0.05)
    this.lastT = now

    // Ease-out: the corridor rushes out of the vanishing point and settles slowly.
    if (this.introLeft > 0) {
      this.introLeft = Math.max(0, this.introLeft - dt)
      this.introOffset = this.RINGS * Math.pow(this.introLeft / this.INTRO, 3)
    }

    this.litAmt = this.lerp(this.litAmt, this.litTarget, this.reduce ? 1 : 0.1)
    if (Math.abs(this.litTarget - this.litAmt) < 0.002) this.litAmt = this.litTarget
    this.px = this.lerp(this.px, this.tpx, 0.1)
    this.py = this.lerp(this.py, this.tpy, 0.1)

    this.render()

    const settled = this.introLeft === 0 && this.litAmt === this.litTarget &&
      Math.abs(this.tpx - this.px) < 0.004 && Math.abs(this.tpy - this.py) < 0.004
    if (settled) this.running = false
    else this.raf = requestAnimationFrame(this._tick)
  }

  kick() {
    if (this.running) return
    this.running = true
    this.lastT = performance.now()
    this.raf = requestAnimationFrame(this._tick)
  }
}
