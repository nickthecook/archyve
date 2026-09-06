import { Controller } from "@hotwired/stimulus"

// The landing's signature: an infinite triangular corridor into the archive.
// Flat-bottom triangles at geometric (perspective) depth that recycles, so we can
// dolly forever. Every ring is driven each frame from one scalar `current` (how
// far we've walked). Typing walks you in, deleting walks you back out; focusing
// lights the far end; the pointer shifts the vanishing point. All on one rAF loop
// that sleeps when nothing's moving.
export default class extends Controller {
  static targets = ["rings", "input"]

  connect() {
    this.NS = "http://www.w3.org/2000/svg"
    this.reduce = matchMedia("(prefers-reduced-motion: reduce)").matches

    const apex = [300, 44], bl = [70, 476], br = [530, 476]
    this.cx = (apex[0] + bl[0] + br[0]) / 3
    this.cy = (apex[1] + bl[1] + br[1]) / 3
    this.V = [apex, br, bl]

    this.RINGS = 16
    this.RATIO = 0.8
    this.NEAR = -1.6
    this.FAR = this.NEAR + this.RINGS
    this.cool = [42, 58, 78]
    this.warm = [242, 196, 99]

    this.polys = []
    for (let i = 0; i < this.RINGS; i++) {
      const p = document.createElementNS(this.NS, "polygon")
      this.ringsTarget.appendChild(p)
      this.polys.push({ el: p, i })
    }

    this.current = this.reduce ? 0 : 3   // rush into place on load
    this.advance = 0
    this.litAmt = 0
    this.litTarget = 0
    this.px = 0; this.py = 0; this.tpx = 0; this.tpy = 0
    this.lastLen = 0
    this.running = false

    this._tick = this.tick.bind(this)
    this.render()
    this.kick()
  }

  disconnect() {
    if (this.raf) cancelAnimationFrame(this.raf)
  }

  // --- input wiring (Stimulus actions call these) ---------------------------
  step() {
    let s = this.inputTarget.value.length - this.lastLen
    this.lastLen = this.inputTarget.value.length
    if (s === 0) s = 1
    this.advance = this.clamp(this.advance + s, this.current - 5, this.current + 5)
    this.kick()
  }

  light() {
    this.lastLen = this.inputTarget.value.length
    this.element.classList.add("is-lit")
    this.litTarget = 1
    this.kick()
  }

  dim() {
    this.element.classList.remove("is-lit")
    this.litTarget = 0
    this.kick()
  }

  peer(event) {
    if (this.reduce) return
    const r = this.ringsTarget.getBoundingClientRect()
    this.tpx = (event.clientX - (r.left + r.width / 2)) / r.width
    this.tpy = (event.clientY - (r.top + r.height / 2)) / r.height
    this.kick()
  }

  rest() { this.tpx = 0; this.tpy = 0; this.kick() }

  // --- engine ---------------------------------------------------------------
  clamp(v, a, b) { return Math.min(b, Math.max(a, v)) }
  lerp(a, b, t) { return a + (b - a) * t }
  mix(a, b, t) {
    return `rgb(${Math.round(this.lerp(a[0], b[0], t))},${Math.round(this.lerp(a[1], b[1], t))},${Math.round(this.lerp(a[2], b[2], t))})`
  }

  drawRing(o) {
    let p = o.i - this.current
    while (p < this.NEAR) p += this.RINGS
    while (p >= this.FAR) p -= this.RINGS
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
    o.el.setAttribute("stroke", this.mix(this.cool, this.warm, warmth))
    o.el.setAttribute("stroke-width", this.clamp(4.4 * Math.pow(Math.min(s, 1.3), 0.8), 0.25, 5.5).toFixed(2))
    o.el.setAttribute("opacity", op.toFixed(3))
  }

  render() { for (const o of this.polys) this.drawRing(o) }

  tick() {
    const e = this.reduce ? 1 : 0.16
    this.current = this.lerp(this.current, this.advance, e)
    if (Math.abs(this.advance - this.current) < 0.0008) this.current = this.advance
    this.litAmt = this.lerp(this.litAmt, this.litTarget, this.reduce ? 1 : 0.1)
    if (Math.abs(this.litTarget - this.litAmt) < 0.002) this.litAmt = this.litTarget
    this.px = this.lerp(this.px, this.tpx, 0.1)
    this.py = this.lerp(this.py, this.tpy, 0.1)

    this.render()

    const still = this.current === this.advance && this.litAmt === this.litTarget &&
      Math.abs(this.tpx - this.px) < 0.004 && Math.abs(this.tpy - this.py) < 0.004
    if (still) {
      this.running = false
      const n = Math.round(this.current / this.RINGS) * this.RINGS
      this.current -= n; this.advance -= n
    } else {
      this.raf = requestAnimationFrame(this._tick)
    }
  }

  kick() { if (!this.running) { this.running = true; this.raf = requestAnimationFrame(this._tick) } }
}
