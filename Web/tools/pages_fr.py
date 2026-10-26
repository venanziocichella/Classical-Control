"""Page definitions of the frequency response demos (Chapter 7)."""

FR_PAGES = {}

FR_PAGES['servo'] = dict(
    title='Servo Frequency Response', h1='Frequency response: DC motor speed servo',
    lead='A sinusoidal voltage drives the motor. At low frequency the speed follows (×K, in phase); above the corner 1/τ it shrinks and lags by up to 90°.',
    matlab='Frequency Response/Servo (First Order)/FR_Servo_Demo.m',
    js=r"""
// DC motor speed servo, first order low-pass: G(s) = K/(tau s + 1).
const K = 5;    // DC gain [rad/s per V]

FreqSim.run({
  w0: 1, wRange: [0.1, 300], A0: 1, ARange: [0.2, 2],
  p0: 0.2, pRange: [0.05, 1], pName: 'Time constant τ',
  model: tau => ({
    A: [[-1 / tau, 0], [1, 0]], B: [K / tau, 0], C: [1, 0], D: 0,   // state [speed, angle]
    num: [K], den: [tau, 1], wc: 1 / tau, settle: 5 * tau,
    paramText: 'τ = ' + ControlSim.fmt(tau) + ' s   (corner 1/τ = ' + ControlSim.fmt(1 / tau) + ' rad/s)',
    ampNote: 'amplified (|G| > 1) for ω < √(K²−1)/τ = ' + ControlSim.fmt(Math.sqrt(K * K - 1) / tau) + ' rad/s'
  }),
  systemText: 'G(s) = W(s)/V(s) = K/(τs + 1), K = 5 rad/s per V. Input: armature voltage v. Output: shaft speed ωm.',
  uText: 'voltage v(t)', uUnit: '(V)', uSym: 'v(t) [V]', ySym: 'ωm(t) [rad/s]', plotLabel: 'v [V],  ωm [rad/s]',
  cornerSym: '1/τ',
  helpText: 'Low frequencies: speed = K · voltage. High frequencies: the rotor inertia cannot follow.',
  sceneLabel: 'motor with a disk, voltage and speed gauges',
  bounds: [-3.2, 3.2, -1.75, 1.75],
  drawScene(g, s) {
    const c = s.colors, A2 = s.ARange[1];
    for (const xg of [-2.7, 2.75]) { g.rect(xg - 0.18, -1.3, 0.36, 2.6, c.panel, c.metal); g.line([[xg - 0.25, 0], [xg + 0.25, 0]], c.fg, 1); }
    g.rect(-2.85, 0, 0.3, 1.2 * s.u / A2, c.muted);
    g.rect(2.6, 0, 0.3, 1.2 * s.y / (K * A2), c.out);
    g.text('voltage v', -2.7, -1.5, { size: 13 }); g.text('speed ωm', 2.75, -1.5, { size: 13 });
    g.rect(-2.1, -0.55, 1.4, 1.1, '#73787f', c.fg);
    g.text('DC motor', -1.4, 0, { size: 12, weight: 700, color: '#ffffff' });
    g.line([[-0.7, 0], [0.6, 0]], c.fg, 6);
    const cx = 1.15, R = 1.05, th = s.x[1];
    g.circle(cx, 0, R, c.panel, c.fg, 1.5);
    for (let k = 0; k < 3; k++) { const a = th + 2 * Math.PI * k / 3; g.line([[cx, 0], [cx + R * Math.cos(a), R * Math.sin(a)]], c.metal, 2); }
    g.line([[cx, 0], [cx + 0.95 * R * Math.cos(th), 0.95 * R * Math.sin(th)]], c.alert, 4);
  }
});
""")

FR_PAGES['spring-damper'] = dict(
    title='Spring-Damper Frequency Response', h1='Frequency response: spring and damper in series',
    lead='You move the end of a damper; a spring holds the plate. Slow motion: the damper slides and the plate stays (high-pass). Fast motion: the damper acts like a rod and the plate follows.',
    matlab='Frequency Response/Spring Damper (High Pass)/FR_SpringDamper_Demo.m',
    js=r"""
// Spring and damper in series, high-pass: G(s) = tau s/(tau s + 1), tau = c/k.
const k = 10;   // spring stiffness [N/m]

FreqSim.run({
  w0: 0.1, wRange: [0.01, 100], A0: 0.3, ARange: [0.1, 0.5],
  p0: 1, pRange: [0.1, 5], pName: 'Time constant τ = c/k',
  model: tau => ({
    // state q = x_in - x (damper stroke, the low-pass part): q' = (x_in - q)/tau, x = x_in - q
    A: [[-1 / tau]], B: [1 / tau], C: [-1], D: 1,
    num: [tau, 0], den: [tau, 1], wc: 1 / tau, settle: 5 * tau,
    paramText: 'τ = c/k = ' + ControlSim.fmt(tau) + ' s   (c = ' + ControlSim.fmt(tau * k) + ' N s/m)',
    ampNote: 'never amplified: |G(jω)| < 1 for every ω'
  }),
  systemText: 'G(s) = X(s)/Xin(s) = τs/(τs + 1), τ = c/k, k = 10 N/m. Input: hand position xin. Output: plate position x.',
  uText: 'hand xin(t)', uUnit: '(m)', uSym: 'xin(t) [m]', ySym: 'x(t) [m]', plotLabel: 'xin, x [m]',
  cornerSym: '1/τ',
  helpText: 'Slow: the damper slides and the plate stays. Fast: the damper behaves like a rigid rod and the plate follows. |G| ≤ 1 always.',
  sceneLabel: 'wall, spring, plate, damper and hand',
  bounds: [-3.3, 3.3, -1.2, 1.4],
  drawScene(g, s) {
    const c = s.colors, S = 0.8 / s.ARange[1], n0 = -0.9, h0 = 1.9;
    const xn = n0 + S * s.y, xh = h0 + S * s.u;
    g.rect(-3.3, -0.7, 0.3, 1.4, c.metal);
    for (const xr of [n0, h0]) g.line([[xr, -0.95], [xr, -0.75]], c.fg, 1);
    g.text('x = 0', n0, -1.07, { size: 12, mono: true }); g.text('xin = 0', h0, -1.07, { size: 12, mono: true });
    g.line(g.zigzag(-3, xn - 0.08, 0, 0.1, 9), c.fg, 2);
    g.rect(xn - 0.08, -0.55, 0.16, 1.1, c.out, c.fg);
    const c0 = xn + 0.08, c1 = xn + 1.95, hc = 0.28, pp = xh - 1.6;
    g.rect(c0, -0.9 * hc, pp - c0, 1.8 * hc, '#f6d58c');
    g.line([[c1, hc], [c0, hc], [c0, -hc], [c1, -hc]], c.fg, 2.5);
    g.line([[pp, -0.9 * hc], [pp, 0.9 * hc]], c.fg, 5);
    g.line([[pp, 0], [xh, 0]], c.metal, 3);
    g.rect(xh, -0.3, 0.35, 0.6, c.alert, c.fg);
    g.text('k', -2.1, 0.45, { size: 15, mono: true }); g.text('c', c0 + 0.3, 0.5, { size: 15, mono: true });
    g.text('x', xn, 0.85, { size: 15, mono: true, color: c.out }); g.text('xin (hand)', xh + 0.18, 0.6, { size: 14, mono: true, color: c.alert });
  }
});
""")

FR_PAGES['mass-spring-damper'] = dict(
    title='Resonance Demo', h1='Frequency response: mass-spring-damper',
    lead='A sinusoidal force pushes the mass. Slow forcing: the mass follows the dashed block (F/k). Near ωn: resonance. Fast forcing: the mass barely moves, opposite to the force.',
    matlab='Frequency Response/Mass Spring Damper (Second Order)/FR_MSD_Demo.m',
    js=r"""
// Force-driven mass-spring-damper; input shown as the static deflection F/k:
// G(s) = wn^2/(s^2 + 2 zeta wn s + wn^2), wn = sqrt(k/m), zeta = c/(2 sqrt(k m)).
const m = 1, k = 10, wn = Math.sqrt(k / m);

FreqSim.run({
  w0: 1, wRange: [0.1, 50], A0: 0.15, ARange: [0.05, 0.3],
  p0: 0.1, pRange: [0.05, 1], pName: 'Damping ratio ζ',
  model: z => ({
    A: [[0, 1], [-wn * wn, -2 * z * wn]], B: [0, wn * wn], C: [1, 0], D: 0,
    num: [wn * wn], den: [1, 2 * z * wn, wn * wn], wc: wn, settle: 4 / (z * wn),
    Mr: z < 1 / Math.SQRT2 ? 1 / (2 * z * Math.sqrt(1 - z * z)) : 1,
    paramText: 'ζ = ' + z.toFixed(2) + '   (c = ' + ControlSim.fmt(2 * z * Math.sqrt(k * m)) + ' N s/m)',
    ampNote: z < 1 / Math.SQRT2 ? 'amplified (|G| > 1) for ω < ωn√(2−4ζ²) = ' + ControlSim.fmt(wn * Math.sqrt(2 - 4 * z * z)) + ' rad/s'
      : 'never amplified for ζ ≥ 1/√2'
  }),
  systemText: 'G(s) = X(s)/(F(s)/k) = ωn²/(s² + 2ζωn s + ωn²), m = 1 kg, k = 10 N/m, ωn = 3.16 rad/s. Input: force as F/k. Output: position x.',
  uText: 'force F(t)/k', uUnit: '(F0/k, m)', uSym: 'F(t)/k [m]', ySym: 'x(t) [m]', plotLabel: 'F/k, x [m]',
  cornerSym: 'ωn',
  helpText: 'Dashed block: where the mass would be if the force changed slowly (F/k). Near ωn the spring and the mass trade energy: resonance.',
  sceneLabel: 'mass on a spring and damper pushed by a force',
  bounds: [-3.3, 3.3, -1.3, 1.5],
  drawScene(g, s) {
    const c = s.colors, S = 1.3 / (s.ARange[1] * s.M.Mr), x0 = 0.2, wB = 0.9, hB = 0.9, yb = -0.8;
    g.rect(-3.3, -0.8, 0.3, 1.8, c.metal);
    g.line([[-3, -0.8], [3.3, -0.8]], c.metal, 2);
    g.line([[x0, -0.8], [x0, -1.0]], c.fg, 1); g.text('x = 0', x0, -1.12, { size: 12, mono: true });
    const xb = x0 + S * s.y, xl = xb - wB / 2;
    g.line(g.zigzag(-3, xl, 0.35, 0.1, 10), c.fg, 2);
    const gap = xl + 3, yd = -0.3, hc = 0.09, c0 = -3 + 0.2 * gap, c1 = -3 + 0.65 * gap, pp = -3 + 0.5 * gap;
    g.line([[-3, yd], [c0, yd]], c.fg, 2);
    g.line([[c1, yd + hc], [c0, yd + hc], [c0, yd - hc], [c1, yd - hc]], c.fg, 2);
    g.line([[pp, yd - 0.8 * hc], [pp, yd + 0.8 * hc]], c.fg, 2);
    g.line([[pp, yd], [xl, yd]], c.fg, 2);
    const xg = x0 + S * s.u - wB / 2;
    g.line([[xg, yb], [xg + wB, yb], [xg + wB, yb + hB], [xg, yb + hB], [xg, yb]], c.muted, 1.5, [6, 4]);
    g.rect(xl, yb, wB, hB, c.out, c.fg);
    g.text('m', xb, yb + hB / 2, { size: 17, mono: true, color: '#ffffff' });
    const Lf = 1.1 * s.u / s.ARange[1], ya = yb + hB + 0.25;
    if (Math.abs(Lf) > 0.05) g.arrow(xb, ya, xb + Lf, ya, c.alert, 4);
    g.text('F(t)', xb, ya + 0.25, { size: 14, mono: true, color: c.alert });
    g.text('k', -1.9, 0.62, { size: 15, mono: true }); g.text('c', -1.9, -0.5, { size: 15, mono: true });
  }
});
""")

FR_PAGES['muffled-song'] = dict(
    title='The Muffled Song', h1='Frequency response: the muffled song',
    lead='Hear a Bode plot. A jungle track plays in a loop through G(s). Lower the corner frequency and the hats and cymbals fade while the bass stays: the song sounds as if behind a wall.',
    matlab='Frequency Response/Muffled Song/FR_Muffled_Song_Demo.m',
    scripts=['engine.js', 'song.js'],
    js=r"""
// Low-pass 1/(tau s + 1), high-pass tau s/(tau s + 1) or resonant wn^2/(s^2 + 2 zeta wn s + wn^2),
// tau = 1/(2 pi fc), wn = 2 pi fc. The music is original, synthesized in the page (FR_Make_Jungle_Track).
SongSim.run({ fc0: 15000, zeta0: 0.1 });
""")
