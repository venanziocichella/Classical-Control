"""Page definitions of the Nyquist demos (Chapter 9)."""

NYQ_PAGES = {}

NYQ_PAGES['contour-mapping'] = dict(
    title='Contour Mapping', h1='Nyquist: mapping contours through L(s)',
    lead='Draw a curve or a closed contour on the s-plane and watch its image L(s) on the L-plane, live. '
         'Count the encirclements of −1, and follow the phasors of the poles and zeros.',
    matlab='Nyquist/Contour Mapping/NYQ_Mapping_Demo.m',
    scripts=['engine.js', 'nyquist.js'],
    js=r"""
// L(s) is typed like C(s) in the other demos: numbers, s, + - * / ^ and parentheses.
// Starts with L(s) = 50/((s+1)(s+2)(s+3)) and the Nyquist contour.
NyquistSim.run({ L: '50/((s+1)*(s+2)*(s+3))' });
""")

NYQ_PAGES['bicycle'] = dict(
    title='Rear-Steered Bicycle', h1='Bicycle with rear-wheel steering',
    lead='Keep a rear-steered bicycle upright by steering. It is unstable and nonminimum phase: '
         'change the speed and see when a controller can (and cannot) keep it up.',
    matlab='Nyquist/Bicycle/BIKE_Realtime_Demo.m',
    scripts=['engine.js'],
    js=r"""
// Rear-steered bicycle (Chapter 1 running example; Astrom, Klein, Lennartsson 2005).
// Point mass at height h, a distance a behind the front contact point; wheelbase b.
// Lean phi (left > 0), rear steering angle delta (rear wheel turned left > 0):
//   h phi'' - g sin(phi) = (V^2/b) delta - (a V/b) delta'
// State x = [phi, z] with z = phi' + (aV/(bh)) delta, so the input derivative is not needed.
const a = 0.5, b = 1, h = 1, g0 = 9.81;
let V = 3;   // forward speed [m/s], set by the slider
const fmt2 = v => (+v.toFixed(3)).toString();

ControlSim.run({
  C0: '9*(s+3)/(s+20)',
  plant: (x, u) => {
    const k = a * V / (b * h);
    return [x[1] - k * u, g0 / h * Math.sin(x[0]) + V * V / (b * h) * u];
  },
  x0: [3 * Math.PI / 180, 0],
  y: x => x[0],
  r: t => 0,
  failed: x => Math.abs(x[0]) > Math.PI / 4,
  failText: 'Fell!',
  uLim: [-0.6, 0.6],                 // rear steering limit [rad] (about ±34°)
  push: 0.3, pushTime: 0.15,         // steering kick from a bump [rad], [s]
  pushNames: ['← Steering kick', 'Steering kick →'],
  G: { num: [1], den: [1] },         // replaced by param.set below
  param: {
    title: 'Speed', label: 'V', min: 0.5, max: 8, step: 0.1, value: 3, unit: ' m/s', digits: 1,
    note: 'The zero V/a moves with the speed; the unstable pole √(g/h) = 3.13 does not. C(s) above was designed for V = 3 m/s. ' +
          'Below a√(g/h) ≈ 1.6 m/s the zero is left of the unstable pole: no stable C(s) can keep the bicycle up.',
    set(v) {
      V = v;
      const k = a * V / (b * h), z = V / a;
      return { num: [-k, k * z], den: [1, 0, -g0 / h],
               text: 'G(s) = (aV/(bh))(V/a − s)/(s² − g/h), a = 0.5 m, b = 1 m, h = 1 m: zero at V/a = ' + fmt2(z) +
                     ', poles ±3.13. Input: rear steering angle δ (±0.6 rad). Output: lean angle φ (left > 0).' };
    }
  },
  loopText: 'The controller sees e = 0 − φ (upright) and steers the rear wheel, δ = C(s) e. Steering into the fall: positive C(s).',
  yLabel: 'lean φ [deg]', yScale: 180 / Math.PI,
  sceneLabel: 'bicycle seen from behind and from above',
  bounds: [-1.15, 2.95, -0.25, 1.4],
  drawScene(g, s) {
    const c = s.colors, ph = s.x[0], dl = s.u;
    // rear view: ground, wheel (edge-on) and rider leaning by phi (left on screen = left of the rider)
    g.line([[-1.15, 0], [1.0, 0]], c.metal, 2);
    g.line([[0, 1.25], [0, 0]], c.ref, 2, [8, 6]);
    const sn = Math.sin(ph), cs = Math.cos(ph);
    g.line([[0, 0], [-0.66 * sn, 0.66 * cs]], c.fg, 9);
    g.line([[-0.66 * sn, 0.66 * cs], [-h * sn, h * cs]], c.fg, 4);
    g.circle(-h * sn, h * cs, 0.09, c.part);
    g.text('rear view', 0, -0.15, { size: 12, color: c.muted });
    // top view (scale q): front contact P, forward = +x, left = +y
    const q = 0.7, yP = 0.75, xP = 2.35, xR = xP - q * b;
    g.line([[xR - 0.3, yP], [xP + 0.2, yP]], c.grid, 1, [4, 4]);
    g.line([[xR, yP], [xP, yP]], c.fg, 3);
    g.line([[xP - 0.2, yP], [xP + 0.2, yP]], c.fg, 8);
    const cd = Math.cos(dl), sd = Math.sin(dl);
    g.line([[xR - 0.2 * cd, yP - 0.2 * sd], [xR + 0.2 * cd, yP + 0.2 * sd]], s.d !== 0 ? c.alert : c.out, 8);
    g.circle(xP - q * a, yP, 0.05, c.part);
    g.text('P', xP, yP + 0.14, { size: 12, color: c.muted });
    g.arrow(xP + 0.28, yP, xP + 0.55, yP, c.muted, 2);
    g.text('V = ' + V.toFixed(1) + ' m/s', xP + 0.15, yP + 0.3, { size: 12, color: c.muted });
    g.text('rear wheel δ = ' + (Math.round(dl * 180 / Math.PI) + 0) + '°', xR, yP - 0.35, { size: 12, color: c.muted });
    g.text('top view', (xR + xP) / 2, -0.15, { size: 12, color: c.muted });
  }
});
""")
