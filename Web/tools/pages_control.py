"""Page definitions of the control demos (one entry per example).

make_pages.py wraps each entry in the common HTML shell. Edit the JavaScript
here (or the generated .html directly, if you prefer to stop regenerating).
"""

PAGES = {}

# ---------------------------------------------------------------- DC motor
PAGES['dc-motor'] = dict(
    title='DC Motor Servo', h1='DC motor servo',
    lead='The shaft follows a commanded angle that changes every 2 s.',
    matlab='DCM_Realtime_Demo.m',
    c0_rh='10', c0_rl='10', c0_bd='65.4*(0.0211*s+1)/(0.00844*s+1)',
    js=r"""
// DC motor from Chapter 1 with L_a = 0 (ball-on-plate servo values).
const K = 1.53;       // steady-state speed gain [rad/(V s)]
const tau = 0.0248;   // time constant [s]
const targets = [90, -90, 180, 0, 45, -135].map(a => a * Math.PI / 180);   // [rad]

ControlSim.run({
  C0: DEFAULT_C,
  // tau*omega' + omega = K v, theta' = omega, state x = [theta, omega]
  plant: (x, u) => [x[1], (K * u - x[1]) / tau],
  x0: [0, 0],
  y: x => x[0],
  r: t => targets[Math.floor(t / 2) % targets.length],   // new command every 2 s
  uLim: [-10, 10],                   // voltage saturation [V]
  push: 4, pushTime: 0.3,            // load disturbance as an equivalent voltage [V], [s]
  pushNames: ['Load torque CW', 'Load torque CCW'],
  G: { num: [K], den: [tau, 1, 0],
       text: 'G(s) = K/(s(τs + 1)), K = 1.53 rad/(V s), τ = 0.0248 s. Input: armature voltage v (±10 V). Output: shaft angle θ.' },
  yLabel: 'θ [deg]', yScale: 180 / Math.PI,
  sceneLabel: 'motor shaft seen from the front',
  bounds: [-1.5, 1.5, -1.3, 1.3],
  drawScene(g, s) {
    const c = s.colors, th = s.x[0];
    g.circle(0, 0, 1.15, c.panel, c.metal, 2);
    for (let a = 0; a < 360; a += 30) {
      const q = a * Math.PI / 180;
      g.line([[1.03 * Math.cos(q), 1.03 * Math.sin(q)], [1.15 * Math.cos(q), 1.15 * Math.sin(q)]], c.metal, 1.5);
    }
    g.line([[0, 0], [1.1 * Math.cos(s.r), 1.1 * Math.sin(s.r)]], c.ref, 3, [8, 6]);
    const ca = Math.cos(th), sa = Math.sin(th), R = (px, py) => [px * ca - py * sa, px * sa + py * ca];
    g.poly([R(0, -0.07), R(1, -0.07), R(1, 0.07), R(0, 0.07)], c.part, c.fg);
    g.circle(0, 0, 0.2, c.fg);
    if (s.d !== 0) {   // curved arrow: direction of the load torque
      const dir = Math.sign(s.d), pts = [];
      for (let k = 0; k <= 15; k++) { const a = th + dir * (0.3 + 0.9 * k / 15); pts.push([0.6 * Math.cos(a), 0.6 * Math.sin(a)]); }
      const a1 = th + dir * 1.2, a2 = th + dir * 1.3;
      g.line(pts, c.alert, 5);
      g.arrow(pts[14][0], pts[14][1], 0.6 * Math.cos(a2), 0.6 * Math.sin(a2), c.alert, 5);
    }
  }
});
""")

# ---------------------------------------------------------------- Car steering
PAGES['car-steering'] = dict(
    title='Car Lane Change', h1='Car lane change',
    lead='The car drives at constant speed and changes lane every 8 s. The controller steers the front wheels.',
    matlab='CAR_Realtime_Demo.m',
    js=r"""
// Car with front-wheel steering from Chapter 1.
const l = 1;        // wheelbase [m]
const v = 1;        // forward speed [m/s]
const lanes = [1, 0, 1, 2, 1, 0].map(k => 2 * k);   // commanded lane centers [m]
let trail = [];

ControlSim.run({
  C0: '2',
  // px' = v cos(theta), py' = v sin(theta), theta' = v/l phi, state x = [px, py, theta]
  plant: (x, u) => [v * Math.cos(x[2]), v * Math.sin(x[2]), v / l * u],
  x0: [0, 0, 0],
  y: x => x[1] + l * Math.sin(x[2]),             // lateral position of the front [m]
  r: t => lanes[Math.floor(t / 8) % lanes.length],
  failed: x => Math.abs(x[1] - 2) > 4,
  failText: 'Off the road!',
  uLim: [-0.5, 0.5],                             // steering angle limits [rad]
  push: 0.3, pushTime: 0.5,                      // side gust as an equivalent steering angle
  pushNames: ['Gust from the left', 'Gust from the right'],
  G: { num: [v, v * v / l], den: [1, 0, 0],
       text: 'G(s) = v(s + v/l)/s², v = 1 m/s, l = 1 m (linearized about θ = 0). Input: steering angle φ (±0.5 rad). Output: lateral position of the front of the car.' },
  yLabel: 'lateral position [m]', yScale: 1,
  sceneLabel: 'car seen from above',
  onReset: () => { trail = []; },
  bounds: s => [s.x[0] - 4, s.x[0] + 12, -2, 7],
  drawScene(g, s) {
    const c = s.colors, [px, py, th] = s.x, x0 = px - 6, x1 = px + 14;
    g.rect(x0, -1, x1 - x0, 6, c.road);
    g.line([[x0, -1], [x1, -1]], '#ffffff', 3); g.line([[x0, 5], [x1, 5]], '#ffffff', 3);
    for (const yl of [1, 3]) for (let xm = Math.floor(x0 / 2) * 2; xm < x1; xm += 2) g.line([[xm, yl], [xm + 1, yl]], '#ffffff', 2);
    g.line([[x0, s.r], [x1, s.r]], c.ref, 2.5, [8, 6]);
    const fx = px + l * Math.cos(th), fy = py + l * Math.sin(th);
    if (!trail.length || Math.hypot(fx - trail[trail.length - 1][0], fy - trail[trail.length - 1][1]) > 0.05) trail.push([fx, fy]);
    if (trail.length > 600) trail.shift();
    g.line(trail, '#f2c230', 1.5);
    const ca = Math.cos(th), sa = Math.sin(th), R = (a, b) => [px + a * ca - b * sa, py + a * sa + b * ca];
    g.poly([R(-0.25, -0.4), R(1.25, -0.4), R(1.25, 0.4), R(-0.25, 0.4)], '#d63a2f', '#222222');
    g.poly([R(0.6, -0.3), R(1.0, -0.3), R(1.0, 0.3), R(0.6, 0.3)], '#b5d6f5');
    for (const yw of [-0.45, 0.45]) g.line([R(-0.15, yw), R(0.15, yw)], '#111111', 4);
    const phi = s.u + s.d;
    for (const yw of [-0.45, 0.45]) g.line([R(l - 0.15 * Math.cos(phi), yw - 0.15 * Math.sin(phi)), R(l + 0.15 * Math.cos(phi), yw + 0.15 * Math.sin(phi))], '#111111', 4);
    g.circle(fx, fy, 0.09, '#f2c230', '#111111');
  }
});
""")

# ---------------------------------------------------------------- Cold storage
PAGES['cold-storage'] = dict(
    title='Cold Storage Room', h1='Cold storage room',
    lead='The AC cools the room to a temperature that changes every 6 s. It can only cool, so P ≥ 0.',
    matlab='CS_Realtime_Demo.m',
    c0_rh='2*(s+1)/s', c0_rl='2*(s+1)/s', c0_bd='2*(s+1)/s',
    js=r"""
// Cold storage unit from Chapter 1. Input u = -P (minus the cooling power).
const h = 1;        // heat transfer constant [1/s]
const Ta = 15;      // ambient temperature [deg C]
const targets = [5, 0, 8, 3];   // commanded temperatures [deg C]
const mix = (a, b, w) => {      // blend two #rrggbb colors
  const p = q => [1, 3, 5].map(i => parseInt(q.slice(i, i + 2), 16));
  const A = p(a), B = p(b);
  return 'rgb(' + A.map((v, i) => Math.round(v * (1 - w) + B[i] * w)).join(',') + ')';
};

ControlSim.run({
  C0: DEFAULT_C,
  plant: (x, u) => [-h * (x[0] - Ta) + u],    // T' = -h (T - Ta) - P = -h (T - Ta) + u
  x0: [15],
  y: x => x[0],
  r: t => targets[Math.floor(t / 6) % targets.length],
  uLim: [-40, 0],                             // u = -P, cooling power P from 0 to 40
  push: -10, pushTime: 1,                     // door: u + 10 (heat), ice: u - 10 (cool)
  pushNames: ['Open the door (heat)', 'Add ice (cool)'],
  G: { num: [1], den: [1, h],
       text: 'G(s) = 1/(s + h), h = 1 1/s, ambient Ta = 15 °C. Input: u = −P, minus the cooling power (P from 0 to 40). Output: room temperature T.' },
  yLabel: 'temperature [°C]', yScale: 1,
  sceneLabel: 'cold room and thermometer',
  bounds: [-5, 7, -1.5, 7.5],
  drawScene(g, s) {
    const c = s.colors, T = s.x[0], a = Math.min(Math.max((T + 5) / 25, 0), 1);
    const hexOf = v => { const m = v.match(/^#([0-9a-f]{6})$/i); return m ? v : '#888888'; };
    g.rect(-4, 0, 6, 5, mix(hexOf(c.cold), hexOf(c.warm), a), c.fg, 3);
    g.rect(-0.5, 0, 1.5, 3.5, s.d > 0 ? '#fff6cc' : '#c4c8cc', c.fg, 1);    // door (open = light)
    g.rect(-3.5, 5, 2, 0.8, '#d9dde1', c.fg, 1);
    g.text('AC', -2.5, 5.4, { weight: 700, color: '#222222' });
    const P = -s.u;                             // cooling power
    const n = Math.round(Math.min(P, 40) / 5);
    for (let i = 1; i <= n; i++) { const xi = -3.5 + 2 * i / (n + 1); g.line([[xi, 4.9], [xi, 4.2]], '#9cc7ff', 2); }
    g.text(T.toFixed(1) + ' °C', -1.6, 2.5, { size: 22, weight: 700, color: '#ffffff' });
    const tm = TT => 0.2 + 5 * (TT + 5) / 25;
    g.rect(4, tm(-5), 1, tm(20) - tm(-5), c.panel, c.fg, 1);
    for (let TT = -5; TT <= 20; TT += 5) { g.line([[5, tm(TT)], [5.3, tm(TT)]], c.fg, 1); g.text(String(TT), 5.45, tm(TT), { size: 11, align: 'left', color: c.muted }); }
    const Tc = Math.min(Math.max(T, -5), 20);
    g.rect(4.2, tm(-5), 0.6, tm(Tc) - tm(-5), '#d02a2a');
    g.line([[3.8, tm(s.r)], [5.2, tm(s.r)]], c.ref, 2.5, [8, 6]);
    g.text('Cooling power P = −u = ' + P.toFixed(1), -1, -0.8, { size: 13, color: c.muted });
  }
});
""")

# ---------------------------------------------------------------- Inverted pendulum
PAGES['inverted-pendulum'] = dict(
    title='Inverted Pendulum', h1='Inverted pendulum',
    lead='Keep the pendulum upright. It starts tilted by 5°; push it to test the controller.',
    matlab='IP_Realtime_Demo.m',
    c0_rh='11.8*(1 + 0.2*s + 0.05/s)/(s/100+1)', c0_rl='390*(1 + 0.1*s)',
    js=r"""
// Inverted pendulum (same values as IP_Control_Design.m).
const g0 = 9.8;     // gravity [m/s^2]
const L = 1;        // pendulum length [m]

ControlSim.run({
  C0: DEFAULT_C,
  plant: (x, u) => [x[1], g0 / L * Math.sin(x[0]) + u],   // theta'' = g/L sin(theta) + u
  x0: [5 * Math.PI / 180, 0],
  y: x => x[0],
  r: t => 0,
  failed: x => Math.abs(x[0]) > Math.PI / 2,
  failText: 'Fell!',
  uLim: [-100, 100],
  push: 8, pushTime: 0.2,
  pushNames: ['← Push left', 'Push right →'],
  G: { num: [1], den: [1, 0, -g0 / L],
       text: 'G(s) = 1/(s² − g/L), g = 9.8 m/s², L = 1 m (linearized upright). Input u (±100). Output: angle θ from vertical.' },
  yLabel: 'θ [deg]', yScale: 180 / Math.PI,
  sceneLabel: 'pendulum on a pivot',
  bounds: [-1.6, 1.6, -0.3, 1.35],
  drawScene(g, s) {
    const c = s.colors, th = s.x[0], bx = L * Math.sin(th), by = L * Math.cos(th);
    g.line([[-1.6, -0.12], [1.6, -0.12]], c.metal, 2);
    g.rect(-0.15, -0.12, 0.3, 0.12, c.metal);
    g.line([[0, 1.25], [0, 0]], c.ref, 2, [8, 6]);
    g.line([[0, 0], [bx, by]], c.fg, 6);
    g.circle(bx, by, 0.08, c.part);
    g.circle(0, 0, 0.04, c.metal);
    if (s.d !== 0) g.arrow(bx - Math.sign(s.d) * 0.4, by, bx - Math.sign(s.d) * 0.1, by, c.alert, 4);
  }
});
""")

# ---------------------------------------------------------------- Mass spring damper
PAGES['mass-spring-damper'] = dict(
    title='Mass Spring Damper', h1='Mass-spring-damper',
    lead='A force u moves the mass to a target position that changes every 4 s.',
    matlab='MSD_Realtime_Demo.m',
    c0_rh='100*(1 + 3/s)', c0_rl='800*(1 + 0/s)', c0_bd='760*(s+1)/(7.14*s+1)',
    js=r"""
// Mass-spring-damper (same values as MSD_Control_Design.m).
const m = 1, b = 8.8, k = 40;   // [kg], [N s/m], [N/m]
const targets = [0.6, -0.4, 1, 0, -0.8, 0.3];

ControlSim.run({
  C0: DEFAULT_C,
  plant: (x, u) => [x[1], (u - b * x[1] - k * x[0]) / m],
  x0: [0, 0],
  y: x => x[0],
  r: t => targets[Math.floor(t / 4) % targets.length],
  uLim: [-300, 300],
  push: 30, pushTime: 0.3,
  pushNames: ['← Push left', 'Push right →'],
  G: { num: [1], den: [m, b, k],
       text: 'G(s) = 1/(m s² + b s + k), m = 1 kg, b = 8.8 N s/m, k = 40 N/m. Input: force u (±300 N). Output: position x.' },
  yLabel: 'position [m]', yScale: 1,
  sceneLabel: 'mass, spring and damper',
  bounds: [-2.1, 1.9, -0.6, 1.0],
  drawScene(g, s) {
    const c = s.colors, xw = -2, wB = 0.4, hB = 0.7, xl = s.x[0] - wB / 2;
    g.rect(-2.1, -0.25, 0.1, 1, c.metal);
    g.line([[xw, -0.25], [1.9, -0.25]], c.metal, 2);
    for (let xt = -1.5; xt <= 1.5001; xt += 0.5) { g.line([[xt, -0.25], [xt, -0.3]], c.muted, 1); g.text(String(+xt.toFixed(1)), xt, -0.4, { size: 11, color: c.muted }); }
    g.line([[s.r, -0.25], [s.r, 0.65]], c.ref, 2.5, [8, 6]);
    g.line(g.zigzag(xw, xl, 0.3, 0.08, 12), c.fg, 2);
    const gap = xl - xw, yd = 0.05, hc = 0.07, c0 = xw + 0.15 * gap, c1 = xw + 0.6 * gap, pp = xw + 0.45 * gap;
    g.line([[xw, yd], [c0, yd]], c.fg, 2);
    g.line([[c1, yd + hc], [c0, yd + hc], [c0, yd - hc], [c1, yd - hc]], c.fg, 2);
    g.line([[pp, yd - 0.8 * hc], [pp, yd + 0.8 * hc]], c.fg, 2);
    g.line([[pp, yd], [xl, yd]], c.fg, 2);
    g.rect(xl, -0.25, wB, hB, c.part, c.fg);
    if (s.d !== 0) g.arrow(s.x[0] - Math.sign(s.d) * 0.55, 0.1, s.x[0] - Math.sign(s.d) * 0.25, 0.1, c.alert, 4);
  }
});
""")

# ---------------------------------------------------------------- Pendulum
PAGES['pendulum'] = dict(
    title='Damped Pendulum', h1='Damped pendulum',
    lead='The pendulum hangs from a pivot and is driven to a commanded angle that changes every 4 s.',
    matlab='PEN_Realtime_Demo.m',
    c0_rh='10*(s+2)*(s+3)/(s*(s/100+1))', c0_rl='10*(s+2)*(s+3)/(s*(s/100+1))',
    c0_bd='196*(0.268*s+1)/(0.0537*s+1)*(1.667*s+1)/(12.15*s+1)',
    js=r"""
// Damped pendulum from Chapter 1.
const k = 1, g0 = 9.8, L = 1;   // damping [1/s], gravity [m/s^2], length [m]
const targets = [30, -30, 60, 0, -45, 15].map(a => a * Math.PI / 180);

ControlSim.run({
  C0: DEFAULT_C,
  plant: (x, u) => [x[1], u - k * x[1] - g0 / L * Math.sin(x[0])],
  x0: [0, 0],
  y: x => x[0],
  r: t => targets[Math.floor(t / 4) % targets.length],
  uLim: [-50, 50],
  push: 15, pushTime: 0.3,
  pushNames: ['← Push left', 'Push right →'],
  G: { num: [1], den: [1, k, g0 / L],
       text: 'G(s) = 1/(s² + k s + g/L), k = 1 1/s, g/L = 9.8 1/s² (linearized hanging down). Input u (±50). Output: angle θ, 0 = hanging.' },
  yLabel: 'θ [deg]', yScale: 180 / Math.PI,
  sceneLabel: 'pendulum hanging from a pivot',
  bounds: [-1.4, 1.4, -1.3, 0.35],
  drawScene(g, s) {
    const c = s.colors, th = s.x[0], bx = L * Math.sin(th), by = -L * Math.cos(th);
    g.rect(-0.3, 0, 0.6, 0.1, c.metal);
    g.line([[0, 0], [1.2 * Math.sin(s.r), -1.2 * Math.cos(s.r)]], c.ref, 2.5, [8, 6]);
    g.line([[0, 0], [bx, by]], c.fg, 6);
    g.circle(bx, by, 0.08, c.part);
    g.circle(0, 0, 0.04, c.metal);
    if (s.d !== 0) g.arrow(bx - Math.sign(s.d) * 0.4, by, bx - Math.sign(s.d) * 0.1, by, c.alert, 4);
  }
});
""")

# ---------------------------------------------------------------- Satellite
PAGES['satellite'] = dict(
    title='Satellite Attitude', h1='Satellite attitude',
    lead='Thrusters turn the satellite to an orientation that changes every 6 s. No friction, no gravity.',
    matlab='SAT_Realtime_Demo.m',
    js=r"""
// Simplified satellite from Chapter 1.
const I = 1;        // moment of inertia [kg m^2]
const targets = [90, 0, -45, 45, 180, 0].map(a => a * Math.PI / 180);
const stars = Array.from({ length: 60 }, (_, i) => [((i * 97) % 320) / 100 - 1.6, ((i * 53) % 260) / 100 - 1.25]);

ControlSim.run({
  C0: '20*(s+1)/(s+10)',
  plant: (x, u) => [x[1], u / I],
  x0: [0, 0],
  y: x => x[0],
  r: t => targets[Math.floor(t / 6) % targets.length],
  uLim: [-10, 10],
  push: 3, pushTime: 0.3,
  pushNames: ['Thruster pulse CW', 'Thruster pulse CCW'],
  G: { num: [1], den: [I, 0, 0],
       text: 'G(s) = 1/(I s²), I = 1 kg m². Input: torque u (±10 N m). Output: orientation θ (counterclockwise positive).' },
  yLabel: 'θ [deg]', yScale: 180 / Math.PI,
  sceneLabel: 'satellite in space',
  bounds: [-1.6, 1.6, -1.25, 1.35],
  drawScene(g, s) {
    const c = s.colors, th = s.x[0];
    g.rect(-3, -3, 6, 6, c.sky);
    stars.forEach(p => g.circle(p[0], p[1], 0.008, '#c8d2e0'));
    g.line([[0, 0], [1.5, 0]], '#7d8794', 1, [2, 4]);
    g.line([[0, 0], [1.5 * Math.cos(s.r), 1.5 * Math.sin(s.r)]], c.ref, 2.5, [8, 6]);
    const ca = Math.cos(th), sa = Math.sin(th), R = (a, b) => [a * ca - b * sa, a * sa + b * ca];
    for (const sg of [-1, 1]) {
      g.poly([R(sg * 0.35, -0.15), R(sg * 1.2, -0.15), R(sg * 1.2, 0.15), R(sg * 0.35, 0.15)], '#28407a', '#9aa4b0');
      for (let k = 1; k <= 4; k++) { const xg = sg * (0.35 + k * 0.17); g.line([R(xg, -0.15), R(xg, 0.15)], '#9aa4b0', 1); }
    }
    g.circle(0, 0, 0.35, '#cfd4da', '#4a5058', 1.5);
    g.line([[0, 0], R(0.32, 0)], c.part, 3);
    if (s.d !== 0) {
      const tip = R(1.2, 0), n = [-Math.sign(s.d) * -sa, -Math.sign(s.d) * ca];
      g.line([tip, [tip[0] + 0.3 * n[0], tip[1] + 0.3 * n[1]]], '#ff7a3d', 6);
    }
  }
});
""")

# ---------------------------------------------------------------- Two mass system
PAGES['two-mass'] = dict(
    title='Two-Mass System', h1='Two-mass system',
    lead='A force on mass 1 moves it to a commanded position; mass 2 swings on the spring between them.',
    matlab='TM_Realtime_Demo.m',
    js=r"""
// Two-mass system from Chapter 1 (wall - k1 - m1 - k2 - m2 - b - wall). Chosen values.
const m1 = 1, m2 = 1, k1 = 1, k2 = 1, b = 0.5;
const targets = [0.5, -0.5, 1, 0];
const conv = (p, q) => p.flatMap((a, i) => q.map((bb, j) => [i + j, a * bb])).reduce((r, [k, v]) => { r[k] = (r[k] || 0) + v; return r; }, []);
const n2 = [m2, b, k2], den = conv(n2, [m1, 0, k1 + k2]);
den[den.length - 1] -= k2 * k2;

ControlSim.run({
  C0: '5*(s+1)^2/(s*(s/20+1))',
  plant: (x, u) => [x[1], (u + k2 * x[2] - (k1 + k2) * x[0]) / m1, x[3], (k2 * x[0] - b * x[3] - k2 * x[2]) / m2],
  x0: [0, 0, 0, 0],
  y: x => x[0],
  r: t => targets[Math.floor(t / 10) % targets.length],
  uLim: [-20, 20],
  push: 3, pushTime: 0.5,
  pushNames: ['← Push mass 1 left', 'Push mass 1 right →'],
  G: { num: n2, den: den,
       text: 'G(s) = X₁/U = (m₂s² + bs + k₂)/((m₂s² + bs + k₂)(m₁s² + k₁ + k₂) − k₂²), all masses and springs 1, b = 0.5. Input: force on mass 1 (±20 N). Output: x₁.' },
  yLabel: 'x₁ [m]', yScale: 1,
  sceneLabel: 'two masses between walls',
  bounds: [-3.2, 3.2, -0.9, 1.3],
  drawScene(g, s) {
    const c = s.colors, xL = -3, xR = 3, w = 0.6, hB = 0.6, p1 = -1 + s.x[0], p2 = 1 + s.x[2];
    g.rect(-3.2, -0.25, 0.2, 1, c.metal); g.rect(xR, -0.25, 0.2, 1, c.metal);
    g.line([[xL, -0.25], [xR, -0.25]], c.metal, 2);
    g.line([[-1 + s.r, -0.25], [-1 + s.r, 0.65]], c.ref, 2.5, [8, 6]);
    g.line(g.zigzag(xL, p1 - w / 2, 0.05, 0.07), c.fg, 2);
    g.line(g.zigzag(p1 + w / 2, p2 - w / 2, 0.15, 0.07), c.fg, 2);
    const a = p2 + w / 2, gap = xR - a, yd = 0.05, hc = 0.07, c0 = xR - 0.15 * gap, c1 = xR - 0.6 * gap, pp = xR - 0.45 * gap;
    g.line([[xR, yd], [c0, yd]], c.fg, 2);
    g.line([[c1, yd + hc], [c0, yd + hc], [c0, yd - hc], [c1, yd - hc]], c.fg, 2);
    g.line([[pp, yd - 0.8 * hc], [pp, yd + 0.8 * hc]], c.fg, 2);
    g.line([[pp, yd], [a, yd]], c.fg, 2);
    g.rect(p1 - w / 2, -0.25, w, hB, c.part, c.fg); g.text('m₁', p1, 0.05, { weight: 700, color: '#ffffff' });
    g.rect(p2 - w / 2, -0.25, w, hB, c.part2, c.fg); g.text('m₂', p2, 0.05, { weight: 700, color: '#ffffff' });
    if (s.d !== 0) g.arrow(p1 - Math.sign(s.d) * 0.7, 0.5, p1 - Math.sign(s.d) * 0.35, 0.5, c.alert, 4);
  }
});
""")

# ---------------------------------------------------------------- Water tank
PAGES['water-tank'] = dict(
    title='Water Tank Level', h1='Water tank level',
    lead='The inflow fills the tank to a level that changes every 20 s. The tank is drawn to scale. Try 5× speed.',
    matlab='WT_Realtime_Demo.m',
    js=r"""
// Water tank from Chapter 1.
const A = 10;       // cross-section [m^2]
const k = 0.5;      // outflow coefficient, Q_out = k h [m^2/s]
const H = 20;       // tank height [m]
const targets = [10, 15, 5, 12];

ControlSim.run({
  C0: '5*(1 + 0.05/s)',
  plant: (x, u) => [(u - k * x[0]) / A * ((x[0] > 0 || u > k * x[0]) ? 1 : 0)],   // h >= 0
  x0: [0],
  y: x => x[0],
  r: t => targets[Math.floor(t / 20) % targets.length],
  failed: x => x[0] > H,
  failText: 'Overflow!',
  uLim: [0, 20],                    // inflow limits [m^3/s]
  push: 4, pushTime: 5,
  pushNames: ['Open drain (−4 m³/s)', 'Extra supply (+4 m³/s)'],
  G: { num: [1], den: [A, k],
       text: 'G(s) = 1/(A s + k), A = 10 m², k = 0.5 m²/s. Input: inflow Q_in (0 to 20 m³/s). Output: level h (tank height 20 m).' },
  yLabel: 'level h [m]', yScale: 1,
  window: 60,
  sceneLabel: 'water tank with inflow and outflow pipes',
  bounds: [-12, 12, -3, 26],
  drawScene(g, s) {
    const c = s.colors, w = 6, h = Math.max(s.x[0], 0), q = s.u + s.d;
    g.rect(-w, 0, 2 * w, h, c.water);
    g.line([[-w, H + 1], [-w, 0], [w, 0], [w, H + 1]], c.fg, 3);
    for (let hh = 0; hh <= H; hh += 5) { g.line([[w, hh], [w + 0.6, hh]], c.muted, 1); g.text(hh + ' m', w + 0.9, hh, { size: 11, align: 'left', color: c.muted }); }
    g.line([[-w, s.r], [w, s.r]], c.ref, 2.5, [8, 6]);
    g.line([[-11, H + 3], [-w + 1, H + 3], [-w + 1, H + 2]], c.metal, 6);
    g.line([[w, 0.5], [11, 0.5]], c.metal, 6);
    if (q > 0.05) g.line([[-w + 1, H + 2], [-w + 1, h]], c.water, Math.max(0.5, 0.6 * q));
    g.line([[11, 0.5], [11.5, -2.5]], c.water, Math.max(0.5, 0.6 * k * h));
    g.text('Q_in = ' + Math.max(q, 0).toFixed(1) + ' m³/s    Q_out = ' + (k * h).toFixed(1) + ' m³/s', -11, H + 4.8, { size: 13, align: 'left', color: c.muted });
  }
});
""")

# ---------------------------------------------------------------- Ball on plate
PAGES['ball-on-plate'] = dict(
    title='Ball on Plate', h1='Ball on plate: you vs the controller',
    lead='Keep the ball on the green target by tilting the plate yourself, then hand it to C(s). The same controller acts on the x and y axes.',
    matlab='BOP_Realtime_Demo.m',
    js=r"""
// Ball on plate from Chapter 1 (values from the Quanser ball balancer lab).
const c = 1.09;      // ball acceleration per servo angle [m/s^2/rad]
const K = 1.53;      // servo gain [rad/(V s)]
const tau = 0.0248;  // servo time constant [s]
const Kp1 = 76.5;    // inner servo loop gain [V/rad]
const Vmax = 10;     // servo voltage saturation [V]
const half = 0.14;   // half side of the plate [m]
const thMax = 0.5;   // servo angle command limit [rad]
const targets = [[0, 0], [0.06, 0.06], [-0.06, 0.06], [-0.06, -0.06], [0.06, -0.06]];
const targetPeriod = 4, tol = 0.015;
const clamp = (v, a) => Math.max(-a, Math.min(a, v));

ControlSim.runGame({
  C0: '3*(s+1)/(s/20+1)',
  nAxes: 2,
  // per axis z = [position, velocity, servo angle, servo speed], u = servo angle command
  z0: a => [a === 0 ? 0.03 : -0.02, 0, 0, 0],
  plant(z, ref) {
    const V = clamp(Kp1 * (ref - z[2]), Vmax);
    return [z[1], c * Math.sin(z[2]), z[3], (K * V - z[3]) / tau];
  },
  error: (z, a, g) => g.r[a] - z[0],
  combine: (uc, hum, mode) => clamp(mode === 'controller' ? uc + 0.3 * hum : hum, thMax),
  humanMax: 0.3,
  onReset(g) { g.tOn = 0; g.iTarget = 0; g.r = targets[0]; },
  onStep(g, Z, h) {
    if (Math.hypot(Z[0][0] - g.r[0], Z[1][0] - g.r[1]) < tol) g.tOn += h;
    if (Math.floor(g.tUp / targetPeriod) !== Math.floor((g.tUp - h) / targetPeriod)) {
      g.iTarget = (g.iTarget + 1) % targets.length; g.r = targets[g.iTarget];
    }
  },
  failed: Z => Math.abs(Z[0][0]) > half || Math.abs(Z[1][0]) > half,
  failText: () => 'Fell off!',
  score: g => { const p = 100 * g.tOn / Math.max(g.tUp, 1e-9); return { now: 'On target: ' + p.toFixed(0) + '%', metric: p }; },
  bestText: b => 'Best human: ' + b.toFixed(0) + '%',
  helpText: 'Mouse: hold the button on the plate; it tilts toward the pointer. Keyboard: arrows. Gamepad: left stick. In Controller mode your input is a disturbance.',
  G: { num: [c * Kp1 * K], den: [tau, 1, Kp1 * K, 0, 0],
       text: 'G(s) = c/s² · Kp₁K/(τs² + s + Kp₁K): ball (c = 1.09) times the servo with its own P loop (Kp₁ = 76.5). Input: servo angle command (±0.5 rad). Output: ball position, per axis.' },
  loopText: 'Each axis: e = target − ball position, servo angle command = C(s) e.',
  sceneLabel: 'plate seen from above with the ball and target',
  bounds: [-0.2, 0.2, -0.2, 0.2],
  drawScene(g, s) {
    const col = s.colors;
    g.rect(-half, -half, 2 * half, 2 * half, col.panel, col.fg, 2);
    g.line([[-half, 0], [half, 0]], col.grid, 1, [2, 4]); g.line([[0, -half], [0, half]], col.grid, 1, [2, 4]);
    const r = s.g.r || [0, 0];
    g.circle(r[0], r[1], tol, 'rgba(70,150,60,0.28)', col.ref, 2);
    const a = [s.Z[0][2], s.Z[1][2]];
    g.line([[0, 0], [0.25 * a[0], 0.25 * a[1]]], s.mode === 'controller' ? col.ref : col.out, 5);
    g.circle(s.Z[0][0], s.Z[1][0], 0.012, col.part, col.fg);
    g.text('line = plate tilt (downhill)', 0, -0.175, { size: 12, color: col.muted });
  }
});
""")

# ---------------------------------------------------------------- Highwire artist
PAGES['highwire-artist'] = dict(
    title='Highwire Artist', h1='Highwire artist: you vs the controller',
    lead='The artist stands on the wire and balances with a pole. Try it yourself, then hand it to C(s).',
    matlab='HA_Realtime_Demo.m',
    js=r"""
// Highwire artist (same equations as HA_sim.slx). theta: artist tilt, psi: pole angle, u: torque on the pole.
const J = 10.4, l = 1.5, L = 2, m = 5, M = 75, g0 = 9.81;
const theta0 = Math.PI / 1000, fallAngle = 45 * Math.PI / 180;
const uHumanMax = 600, uCtrlMax = 3000;
const Dth = 6 * m * l * l + 2 * M * L * L, kg = 3 * g0 * (2 * m * l + M * L);
const Dpsi = 2 * J * (3 * m * l * l + M * L * L), kpsi = 2 * (3 * J + 3 * m * l * l + M * L * L);
const H = 2 * L, hp = 2.5;   // drawn artist height, height of the hands [m]

ControlSim.runGame({
  C0: '3000*(s+2)/(s+5)',
  nAxes: 1,
  z0: () => [theta0, 0, 0, 0],
  plant: (x, u) => [x[1], (kg * Math.sin(x[0]) + 6 * u) / Dth, x[3], (-kg * Math.sin(x[0]) - kpsi * u) / Dpsi],
  error: z => -z[0],
  combine: (uc, hum, mode) => mode === 'controller' ? Math.max(-uCtrlMax, Math.min(uCtrlMax, uc)) + 0.3 * hum : hum,
  humanMax: uHumanMax,
  failed: Z => Math.abs(Z[0][0]) > fallAngle,
  failText: (g, mode) => mode === 'human' ? 'Fell after ' + g.tUp.toFixed(1) + ' s!' : 'Fell!',
  score: g => ({ now: 'Time on the wire: ' + g.tUp.toFixed(1) + ' s', metric: g.tUp }),
  bestText: b => 'Best human: ' + b.toFixed(1) + ' s',
  helpText: 'Mouse: hold the button on the scene and move left/right. Keyboard: arrows. Gamepad: left stick. In Controller mode your input is a disturbance.',
  G: { num: [6 / Dth], den: [1, 0, -kg / Dth],
       text: 'G(s) = (6/(6ml² + 2ML²)) / (s² − 3g(2ml + ML)/(6ml² + 2ML²)), J = 10.4, l = 1.5 m, L = 2 m, m = 5 kg, M = 75 kg. Input: torque on the pole (±3000 N m). Output: artist tilt θ.' },
  loopText: 'The controller sees e = 0 − θ (upright) and outputs the torque on the pole u = C(s) e.',
  sceneLabel: 'artist on a wire holding a balancing pole',
  bounds: [-5, 5, -2.3, 6],
  drawScene(g, s) {
    const c = s.colors, th = s.Z[0][0], psi = s.Z[0][2], u = s.U[0];
    g.line([[-5, 0], [5, 0]], c.fg, 1.5);
    g.rect(-4.9, -2.3, 0.3, 2.6, '#9a7350'); g.rect(4.6, -2.3, 0.3, 2.6, '#9a7350');
    g.line([[-3, -1.6], [3, -1.6]], c.grid, 8);
    g.line([[0, -1.6], [3 * Math.max(-1.6, Math.min(1.6, u / uHumanMax)), -1.6]], s.mode === 'controller' ? c.ref : c.out, 8);
    g.text('torque', -3.2, -1.6, { size: 12, align: 'right', color: c.muted });
    const ca = Math.cos(th), sa = Math.sin(th), R = (a, b) => [a * ca + b * sa, -a * sa + b * ca];   // rotate by -theta
    g.line([R(-0.08, 0), R(0, 0.45 * H), R(0.08, 0)], c.fg, 4);
    g.line([R(0, 0.45 * H), R(0, 0.85 * H)], c.part, 6);
    g.line([R(-0.45, hp), R(0, 0.8 * H), R(0.45, hp)], c.fg, 3);
    const hd = R(0, 0.94 * H); g.circle(hd[0], hd[1], 0.25, '#f2cfa8', c.fg, 1);
    const pc = [hp * sa, hp * ca], pa = Math.cos(psi), pb = Math.sin(psi), P = (a, b) => [pc[0] + a * pa - b * pb, pc[1] + a * pb + b * pa];
    g.line([P(-3, 0), P(3, 0)], '#6b4423', 4);
    g.poly([P(-3.2, -0.15), P(-2.8, -0.15), P(-2.8, 0.15), P(-3.2, 0.15)], c.metal);
    g.poly([P(2.8, -0.15), P(3.2, -0.15), P(3.2, 0.15), P(2.8, 0.15)], c.metal);
  }
});
""")

# ---------------------------------------------------------------- Inverted pendulum on a cart
PAGES['cart-pendulum'] = dict(
    title='Cart Pendulum', h1='Inverted pendulum on a cart: you vs the controller',
    lead='Keep the pendulum upright by pushing the cart. Try it yourself, then hand it to C(s). The view follows the cart.',
    matlab='IPC_Realtime_Demo.m',
    js=r"""
// Inverted pendulum on a cart (Exercise 4.4). theta from the upward vertical, positive to the right.
const M = 0.5, m = 0.5, l = 0.3, I = 0.006, mu = 0.1, g0 = 9.81;
const theta0 = 2 * Math.PI / 180, fallAngle = 80 * Math.PI / 180;
const uHumanMax = 10, uCtrlMax = 30;
const q = (M + m) * (I + m * l * l) - (m * l) ** 2;
const W = 1.1, wc = 0.3, hc = 0.12, rw = 0.03, Lr = 2 * l, yp = 2 * rw + hc;

ControlSim.runGame({
  C0: '-10*(6 + s + 8/s)/(s/100+1)',
  nAxes: 1,
  z0: () => [theta0, 0, 0, 0],   // [theta, theta', y, y']
  plant(x, u) {
    const cs = Math.cos(x[0]), sn = Math.sin(x[0]);
    const a11 = M + m, a12 = m * l * cs, a22 = I + m * l * l;
    const r1 = u - mu * x[3] + m * l * sn * x[1] * x[1], r2 = m * g0 * l * sn;
    const det = a11 * a22 - a12 * a12;
    const ydd = (r1 * a22 - a12 * r2) / det, thdd = (a11 * r2 - a12 * r1) / det;
    return [x[1], thdd, x[3], ydd];
  },
  error: z => -z[0],
  combine: (uc, hum, mode) => mode === 'controller' ? Math.max(-uCtrlMax, Math.min(uCtrlMax, uc)) + 0.3 * hum : hum,
  humanMax: uHumanMax,
  failed: Z => Math.abs(Z[0][0]) > fallAngle,
  failText: (g, mode) => mode === 'human' ? 'Fell after ' + g.tUp.toFixed(1) + ' s!' : 'Fell!',
  score: g => ({ now: 'Time upright: ' + g.tUp.toFixed(1) + ' s', metric: g.tUp }),
  bestText: b => 'Best human: ' + b.toFixed(1) + ' s',
  helpText: 'Mouse: hold the button on the scene and move left/right. Keyboard: arrows. Gamepad: left stick. In Controller mode your input is a disturbance.',
  G: { num: [-m * l, 0], den: [q, mu * (I + m * l * l), -(M + m) * m * g0 * l, -mu * m * g0 * l],
       text: 'G(s) = −ml s / (q s³ + μ(I + ml²)s² − (M+m)mgl s − μmgl), q = (M+m)(I+ml²) − (ml)²; M = m = 0.5 kg, l = 0.3 m, I = 0.006 kg m², μ = 0.1 N s/m. Input: force on the cart (±30 N). Output: angle θ.' },
  loopText: 'The controller sees e = 0 − θ (upright) and outputs the force on the cart u = C(s) e.',
  sceneLabel: 'pendulum on a cart on a track',
  bounds: s => { const yc = Number.isFinite(s.Z[0][2]) ? s.Z[0][2] : 0; return [yc - W, yc + W, -0.42, 0.9]; },
  drawScene(g, s) {
    const c = s.colors, x = s.Z[0], yc = Number.isFinite(x[2]) ? x[2] : 0, u = s.U[0];
    g.line([[yc - W - 1, 0], [yc + W + 1, 0]], c.metal, 2);
    for (let k = Math.ceil((yc - W) / 0.25); k <= Math.floor((yc + W) / 0.25); k++) g.line([[k * 0.25, 0], [k * 0.25, -0.04]], c.muted, 1);
    g.text(Math.round(yc) + ' m', Math.round(yc), -0.09, { size: 11, color: c.muted });
    g.line([[yc - 0.6, -0.3], [yc + 0.6, -0.3]], c.grid, 8);
    g.line([[yc, -0.3], [yc + 0.6 * Math.max(-1.6, Math.min(1.6, u / uHumanMax)), -0.3]], s.mode === 'controller' ? c.ref : c.out, 8);
    g.text('force', yc - 0.65, -0.3, { size: 12, align: 'right', color: c.muted });
    g.rect(yc - wc / 2, 2 * rw, wc, hc, c.part2, c.fg);
    for (const xw of [-wc / 3, wc / 3]) g.circle(yc + xw, rw, rw, c.fg);
    const tx = yc + Lr * Math.sin(x[0]), ty = yp + Lr * Math.cos(x[0]);
    g.line([[yc, yp], [tx, ty]], c.fg, 6);
    g.circle(tx, ty, 0.03, c.part);
    g.circle(yc, yp, 0.015, c.panel);
  }
});
""")
