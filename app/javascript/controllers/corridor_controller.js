import { Controller } from "@hotwired/stimulus"

// The landing's signature: an infinite triangular corridor into the archive.
// Flat-bottom triangles at geometric (perspective) depth that recycles, so we can
// dolly forever. Rings are driven each frame from one scalar `current` (how far
// we've walked).
//
// Each keystroke walks one slot toward a `target` (typing walks in, deleting
// walks out). Motion follows a trapezoidal velocity profile — accelerate from
// rest, cruise at a constant speed, decelerate to a stop — so a lone keystroke
// eases in and out over ~800ms while continuous typing flows smoothly at a
// steady pace (velocity never drops to zero mid-walk, which is what made
// per-step easing feel jerky). The target's lead over the current position is
// capped, so you can't out-type the walk and it settles about one step after you
// stop. Focus lights the far end; the pointer shifts the vanishing point. One rAF
// loop that sleeps when nothing is moving.
//
// On load the corridor builds itself: every ring starts past the far plane (so the
// frame is empty), then they bloom out of the vanishing point one after another and
// glide outward into their resting slots. Same direction as walking in — forward —
// and it is a pure render offset, so the walk system never sees it.
export default class extends Controller {
  static targets = ["rings", "input"]

  VMAX = 1.3    // slots per second at cruise (≈ one 800ms step when isolated)
  ACCEL = 8     // slots per second² — the ease-in / ease-out ramp
  LEAD = 1.15   // how far target may lead current: a single step, and the max coast after you stop
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
    this.cool = [42, 58, 78]
    this.warm = [242, 196, 99]

    // Start from an empty rings group. Turbo Drive caches the page snapshot with
    // our appended polygons still in it; without this, a Back navigation restores
    // that snapshot and connect() appends a *second* set — a stale ghost corridor
    // over the live one. Clearing first keeps the build idempotent.
    this.ringsTarget.replaceChildren()
    this.polys = []
    for (let i = 0; i < this.RINGS; i++) {
      const p = document.createElementNS(this.NS, "polygon")
      this.ringsTarget.appendChild(p)
      this.polys.push({ el: p, i })
    }

    // Strip the polygons before Turbo snapshots the page, so the cache matches
    // the (empty) server-rendered rings and the Back preview never shows a ghost.
    this._beforeCache = () => this.ringsTarget.replaceChildren()
    document.addEventListener("turbo:before-cache", this._beforeCache)

    this.current = 0
    this.target = 0
    this.vel = 0
    this.litAmt = 0
    this.litTarget = 0
    this.px = 0; this.py = 0; this.tpx = 0; this.tpy = 0
    this.lastLen = 0
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
    this.ringsTarget.replaceChildren()
  }

  // --- input wiring (Stimulus actions) --------------------------------------
  step() {
    const delta = this.inputTarget.value.length - this.lastLen
    this.lastLen = this.inputTarget.value.length
    const dir = delta < 0 ? -1 : 1

    if (this.reduce) { this.current = this.normalize(this.current + dir); this.render(); return }
    this.target = this.clamp(this.target + dir, this.current - this.LEAD, this.current + this.LEAD)
    this.kick()
  }

  light() { this.lastLen = this.inputTarget.value.length; this.element.classList.add("is-lit"); this.litTarget = 1; this.kick() }
  dim() { this.element.classList.remove("is-lit"); this.litTarget = 0; this.kick() }

  peer(event) {
    if (this.reduce) return
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
      this.current = 0; this.target = 0; this.vel = 0
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

  // Phase is periodic in RINGS, so keep the walk counter small (invisible jump).
  normalize(v) { return v - Math.round(v / this.RINGS) * this.RINGS }

  // Trapezoidal follow: accelerate toward target, but start braking once the
  // remaining distance equals our stopping distance, so we ease to a clean stop.
  walk(dt) {
    const rem = this.target - this.current
    const stopDist = (this.vel * this.vel) / (2 * this.ACCEL)
    if (rem === 0 && this.vel === 0) return

    if (Math.abs(rem) <= stopDist || Math.sign(rem) === 0) {
      const braked = this.vel - Math.sign(this.vel) * this.ACCEL * dt
      this.vel = Math.sign(braked) !== Math.sign(this.vel) ? 0 : braked
    } else {
      this.vel = this.clamp(this.vel + Math.sign(rem) * this.ACCEL * dt, -this.VMAX, this.VMAX)
    }
    this.current += this.vel * dt

    if (Math.abs(this.target - this.current) < 0.002 && Math.abs(this.vel) < 0.02) {
      this.current = this.normalize(this.target)
      this.target = this.current
      this.vel = 0
    }
  }

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
    o.el.setAttribute("stroke", this.mix(this.cool, this.warm, warmth))
    o.el.setAttribute("stroke-width", this.clamp(4.4 * Math.pow(Math.min(s, 1.3), 0.8), 0.25, 5.5).toFixed(2))
    o.el.setAttribute("opacity", op.toFixed(3))
  }

  render() { for (const o of this.polys) this.drawRing(o) }

  tick() {
    const now = performance.now()
    const dt = Math.min((now - this.lastT) / 1000, 0.05)
    this.lastT = now

    this.walk(dt)

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

    const settled = this.introLeft === 0 && this.vel === 0 && this.current === this.target && this.litAmt === this.litTarget &&
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
