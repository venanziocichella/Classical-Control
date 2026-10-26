/* engine.js - shared real-time engine for the browser versions of the
 * Classical-Control demos (port of the *_Realtime_Demo.m engine).
 *
 * A page calls ControlSim.run(config) with the parts that differ between
 * examples: the nonlinear plant, its linear model G(s), the reference, the
 * limits, the disturbance and a drawScene() for the animation. Everything
 * else (C(s) parser, state-space realization, RK4 loop, plots, panel) is here.
 *
 * Plain JavaScript, no libraries: the page works offline from a double-click.
 */
(function () {
  'use strict';

  // ---------------------------------------------------------------------
  // Polynomials. Internally: ascending powers, p[k] is the coefficient of s^k.
  // ---------------------------------------------------------------------
  function trim(p) {
    p = p.slice();
    while (p.length > 1 && p[p.length - 1] === 0) p.pop();
    return p;
  }
  function padd(a, b) {
    const n = Math.max(a.length, b.length), r = [];
    for (let k = 0; k < n; k++) r.push((a[k] || 0) + (b[k] || 0));
    return trim(r);
  }
  function pmul(a, b) {
    const r = new Array(a.length + b.length - 1).fill(0);
    for (let i = 0; i < a.length; i++)
      for (let j = 0; j < b.length; j++) r[i + j] += a[i] * b[j];
    return trim(r);
  }
  function pscale(a, c) { return trim(a.map(v => v * c)); }
  function isZero(p) { return p.every(v => v === 0); }
  function same(a, b) { return a.length === b.length && a.every((v, k) => v === b[k]); }

  // Rational functions {n, d}, both ascending. A constant denominator is folded
  // into the numerator, so s/20 + 1 stays 0.05 s + 1 as in MATLAB's tf.
  function norm(a) {
    return a.d.length === 1 ? { n: pscale(a.n, 1 / a.d[0]), d: [1] } : a;
  }
  const R = {
    num: c => ({ n: [c], d: [1] }),
    s: () => ({ n: [0, 1], d: [1] }),
    add(a, b) {
      if (same(a.d, b.d)) return { n: padd(a.n, b.n), d: a.d };
      return norm({ n: padd(pmul(a.n, b.d), pmul(b.n, a.d)), d: pmul(a.d, b.d) });
    },
    neg: a => ({ n: pscale(a.n, -1), d: a.d }),
    mul: (a, b) => norm({ n: pmul(a.n, b.n), d: pmul(a.d, b.d) }),
    div(a, b) {
      if (isZero(b.n)) throw new Error('Division by zero in C(s).');
      return norm({ n: pmul(a.n, b.d), d: pmul(a.d, b.n) });
    },
    pow(a, k) {
      if (k < 0) { a = R.div(R.num(1), a); k = -k; }
      let r = R.num(1);
      for (let i = 0; i < k; i++) r = R.mul(r, a);
      return r;
    }
  };

  // ---------------------------------------------------------------------
  // C(s) parser. Same rules as the MATLAB demos: numbers, s, + - * / ^ and
  // parentheses (MATLAB's .* ./ .^ are accepted too).
  // ---------------------------------------------------------------------
  const HELP = 'Type C(s) with numbers, s, + - * / ^ and parentheses only, e.g. 10*(s+2)/(s+5)';

  function tokenize(str) {
    const toks = [];
    const re = /\s*(?:(\d+\.?\d*(?:[eE][-+]?\d+)?|\.\d+(?:[eE][-+]?\d+)?)|(s)|\.?([-+*/^()]))/y;
    let i = 0;
    str = str.trim();
    while (i < str.length) {
      re.lastIndex = i;
      const m = re.exec(str);
      if (!m) throw new Error(HELP);
      if (m[1] !== undefined) toks.push({ t: 'num', v: parseFloat(m[1]) });
      else if (m[2] !== undefined) toks.push({ t: 's' });
      else toks.push({ t: m[3] });
      i = re.lastIndex;
      while (i < str.length && /\s/.test(str[i])) i++;
    }
    return toks;
  }

  function parseC(str) {
    if (!str.trim()) throw new Error(HELP);
    const toks = tokenize(str);
    let i = 0;
    const peek = () => toks[i] && toks[i].t;
    const fail = () => { throw new Error('Could not read C(s) = ' + str.trim() + '. Example: 10*(s+2)/(s+5)'); };
    function expr() {
      let a = term();
      while (peek() === '+' || peek() === '-') {
        const op = toks[i++].t, b = term();
        a = op === '+' ? R.add(a, b) : R.add(a, R.neg(b));
      }
      return a;
    }
    function term() {
      let a = unary();
      while (peek() === '*' || peek() === '/') {
        const op = toks[i++].t, b = unary();
        a = op === '*' ? R.mul(a, b) : R.div(a, b);
      }
      return a;
    }
    function unary() {
      if (peek() === '-') { i++; return R.neg(unary()); }
      if (peek() === '+') { i++; return unary(); }
      return power();
    }
    function power() {
      const a = primary();
      if (peek() === '^') {
        i++;
        const e = unary();   // as in MATLAB: 2^-1 is allowed, -s^2 is -(s^2)
        if (e.n.length !== 1 || e.d.length !== 1) throw new Error('Exponents must be numbers, e.g. (s+1)^2.');
        const k = e.n[0] / e.d[0];
        if (!Number.isInteger(k)) throw new Error('Exponents must be whole numbers, e.g. (s+1)^2.');
        return R.pow(a, k);
      }
      return a;
    }
    function primary() {
      const tk = toks[i++];
      if (!tk) fail();
      if (tk.t === 'num') return R.num(tk.v);
      if (tk.t === 's') return R.s();
      if (tk.t === '(') {
        const a = expr();
        if (peek() !== ')') fail();
        i++;
        return a;
      }
      fail();
    }
    const r = expr();
    if (i < toks.length) {
      const nx = toks[i].t;
      if (nx === 'num' || nx === 's' || nx === '(') throw new Error('Use * between factors, e.g. 2*s or (s+1)*(s+2).');
      fail();
    }
    if (isZero(r.d)) fail();
    // descending order, as MATLAB's tfdata(..., 'v') (without padding)
    return { num: r.n.slice().reverse(), den: r.d.slice().reverse() };
  }

  // ---------------------------------------------------------------------
  // Controllable canonical realization, same as localTf2ss in the .m files.
  // num, den in descending powers. Improper C(s): roll-off 1/(s/100+1)^k.
  // ---------------------------------------------------------------------
  function stripLead(p) {
    const k = p.findIndex(v => v !== 0);
    return k < 0 ? [0] : p.slice(k);
  }
  function convDesc(a, b) { return pmul(a.slice().reverse(), b.slice().reverse()).reverse(); }

  function tf2ss(num, den) {
    num = stripLead(num); den = stripLead(den);
    const nExtra = Math.max(0, num.length - den.length);
    for (let k = 0; k < nExtra; k++) den = convDesc(den, [0.01, 1]);
    const d0 = den[0];
    num = num.map(v => v / d0); den = den.map(v => v / d0);
    const n = den.length - 1;
    num = new Array(n + 1 - num.length).fill(0).concat(num);
    const D = num[0];
    const r = num.map((v, k) => v - D * den[k]);
    // x' = A x + B e, u = C x + D e, A companion (last row -den reversed)
    const A = [], B = [], C = [];
    for (let i = 0; i < n; i++) {
      const row = new Array(n).fill(0);
      if (i < n - 1) row[i + 1] = 1;
      else for (let j = 0; j < n; j++) row[j] = -den[n - j];
      A.push(row);
      B.push(i === n - 1 ? 1 : 0);
      C.push(r[n - i]);
    }
    return { A, B, C, D, n, nExtra, num, den };
  }

  // ---------------------------------------------------------------------
  // Text of a transfer function, same format as localTfString.
  // ---------------------------------------------------------------------
  function fmt(a) { return String(parseFloat(a.toPrecision(4))); }
  function polyString(p) {
    const n = p.length - 1;
    let str = '';
    p.forEach((a, k) => {
      const e = n - k;
      if (a === 0) return;
      if (!str) { if (a < 0) str = '−'; }
      else str += a < 0 ? ' − ' : ' + ';
      a = Math.abs(a);
      if (a !== 1 || e === 0) str += fmt(a) + (e > 0 ? ' ' : '');
      if (e === 1) str += 's'; else if (e > 1) str += 's' + sup(e);
    });
    return str || '0';
  }
  function sup(e) { return String(e).split('').map(c => '⁰¹²³⁴⁵⁶⁷⁸⁹'[+c]).join(''); }
  function tfParts(num, den) {
    num = stripLead(num); den = stripLead(den);
    if (den.length === 1) return { num: polyString(num.map(v => v / den[0])), den: null };
    return { num: polyString(num), den: polyString(den) };
  }

  // ---------------------------------------------------------------------
  // Polynomial roots (Durand-Kerner), descending coefficients.
  // ---------------------------------------------------------------------
  function roots(p) {
    p = stripLead(p);
    const n = p.length - 1;
    if (n < 1) return [];
    const a = p.map(v => v / p[0]);
    const ev = (zr, zi) => {   // Horner in complex arithmetic
      let re = 1, im = 0;
      for (let k = 1; k <= n; k++) {
        const t = re * zr - im * zi + a[k];
        im = re * zi + im * zr; re = t;
      }
      return [re, im];
    };
    const rad = 1 + Math.max(...a.slice(1).map(Math.abs));
    let z = [];
    for (let k = 0; k < n; k++) {
      const th = 2 * Math.PI * k / n + 0.4;
      z.push([rad * 0.5 * Math.cos(th), rad * 0.5 * Math.sin(th)]);
    }
    for (let it = 0; it < 2000; it++) {
      let delta = 0;
      z = z.map((zk, k) => {
        let [nr, ni] = ev(zk[0], zk[1]);
        let dr = 1, di = 0;
        z.forEach((zj, j) => {
          if (j === k) return;
          const xr = zk[0] - zj[0], xi = zk[1] - zj[1];
          const t = dr * xr - di * xi; di = dr * xi + di * xr; dr = t;
        });
        const m = dr * dr + di * di || 1e-300;
        const qr = (nr * dr + ni * di) / m, qi = (ni * dr - nr * di) / m;
        delta = Math.max(delta, Math.hypot(qr, qi));
        return [zk[0] - qr, zk[1] - qi];
      });
      if (delta < 1e-12 * rad) break;
    }
    return z.map(([re, im]) => [Math.abs(re) < 1e-9 * rad ? 0 : re, Math.abs(im) < 1e-9 * rad ? 0 : im]);
  }


  // ---------------------------------------------------------------------
  // Page helpers
  // ---------------------------------------------------------------------
  function el(tag, attrs, kids) {
    const e = document.createElement(tag);
    for (const k in attrs || {}) {
      if (k === 'text') e.textContent = attrs[k];
      else if (k.startsWith('on')) e.addEventListener(k.slice(2), attrs[k]);
      else e.setAttribute(k, attrs[k]);
    }
    (kids || []).forEach(c => e.append(c));
    return e;
  }
  function fracEl(parts) {
    if (!parts.den) return el('span', { class: 'cs-poly', text: parts.num });
    return el('span', { class: 'cs-frac' }, [
      el('span', { class: 'cs-num', text: parts.num }),
      el('span', { class: 'cs-den', text: parts.den })]);
  }
  function token(name) { return getComputedStyle(document.documentElement).getPropertyValue(name).trim(); }
  function colorsNow() {
    const c = {};
    ['fg', 'muted', 'grid', 'ref', 'out', 'pole', 'unstable-bg', 'part', 'part2', 'metal', 'panel', 'alert',
     'water', 'road', 'sky', 'cold', 'warm', 'font-mono', 'font-body']
      .forEach(n => { c[n.replace(/-(.)/g, (_, a) => a.toUpperCase())] = token('--' + n); });
    c.mono = c.fontMono; c.body = c.fontBody;
    return c;
  }
  function dpr() { return window.devicePixelRatio || 1; }

  function setupCanvas(cv) {
    const ctx = cv.getContext('2d');
    const fit = () => {
      const r = cv.getBoundingClientRect();
      cv.width = Math.max(1, Math.round(r.width * dpr()));
      cv.height = Math.max(1, Math.round(r.height * dpr()));
    };
    new ResizeObserver(fit).observe(cv);
    fit();
    return ctx;
  }

  // Draw a scene in world coordinates (y up). bounds = [x0, x1, y0, y1].
  // The draw function gets helpers: px (one CSS pixel in world units),
  // text(str, x, y, opts), line(pts, color, width, dash), poly(pts, fill, stroke),
  // circle(x, y, r, fill, stroke), arrow(x0, y0, x1, y1, color, width).
  function drawWorld(cv, ctx, bounds, draw, state) {
    const W = cv.width, H = cv.height;
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, W, H);
    const [x0, x1, y0, y1] = bounds;
    const s = Math.min(W / (x1 - x0), H / (y1 - y0));
    ctx.setTransform(s, 0, 0, -s, W / 2 - s * (x0 + x1) / 2, H / 2 + s * (y0 + y1) / 2);
    const px = dpr() / s;
    const g = {
      ctx, px,
      text(str, x, y, o = {}) {
        ctx.save(); ctx.translate(x, y); ctx.scale(px, -px);
        if (o.rotate) ctx.rotate(-o.rotate);
        ctx.font = (o.weight || '400') + ' ' + (o.size || 13) + 'px ' + (o.mono ? state.colors.mono : state.colors.body);
        ctx.fillStyle = o.color || state.colors.fg;
        ctx.textAlign = o.align || 'center'; ctx.textBaseline = o.baseline || 'middle';
        ctx.fillText(str, 0, 0); ctx.restore();
      },
      line(pts, color, width = 2, dash) {
        ctx.beginPath();
        let pen = false;
        pts.forEach(p => {
          if (!p || !Number.isFinite(p[0]) || !Number.isFinite(p[1])) { pen = false; return; }
          pen ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1]); pen = true;
        });
        ctx.strokeStyle = color; ctx.lineWidth = width * px; ctx.lineJoin = 'round'; ctx.lineCap = 'round';
        ctx.setLineDash(dash ? dash.map(v => v * px) : []); ctx.stroke(); ctx.setLineDash([]);
      },
      poly(pts, fill, stroke, width = 1) {
        ctx.beginPath(); pts.forEach((p, k) => k ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1])); ctx.closePath();
        if (fill) { ctx.fillStyle = fill; ctx.fill(); }
        if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = width * px; ctx.stroke(); }
      },
      rect(x, y, w, h, fill, stroke, width) { g.poly([[x, y], [x + w, y], [x + w, y + h], [x, y + h]], fill, stroke, width); },
      circle(x, y, r, fill, stroke, width = 1) {
        ctx.beginPath(); ctx.arc(x, y, r, 0, 2 * Math.PI);
        if (fill) { ctx.fillStyle = fill; ctx.fill(); }
        if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = width * px; ctx.stroke(); }
      },
      arrow(xa, ya, xb, yb, color, width = 4) {
        const L = Math.hypot(xb - xa, yb - ya); if (L < 1e-9) return;
        const ux = (xb - xa) / L, uy = (yb - ya) / L, hl = Math.min(L * 0.6, 12 * px), hw = 6 * px;
        g.line([[xa, ya], [xb - ux * hl * 0.8, yb - uy * hl * 0.8]], color, width);
        g.poly([[xb, yb], [xb - ux * hl - uy * hw, yb - uy * hl + ux * hw], [xb - ux * hl + uy * hw, yb - uy * hl - ux * hw]], color);
      },
      zigzag(xa, xb, y, amp, n = 8) {
        const pts = [];
        for (let k = 0; k <= 2 * n; k++) {
          const yy = k === 0 || k === 2 * n ? y : y + amp * (k % 2 ? 1 : -1);
          pts.push([xa + (xb - xa) * k / (2 * n), yy]);
        }
        return pts;
      }
    };
    draw(g, state);
  }

  // Controller and closed-loop poles sections, shared by both kinds of demo.
  function controllerPanel(cfg, onApply) {
    const self = {};
    const gBox = el('div', { class: 'cs-tf' }, [el('span', { class: 'cs-lhs', text: 'G(s) =' }), fracEl(tfParts(cfg.G.num, cfg.G.den))]);
    const cInput = el('input', { id: 'c-input', class: 'cs-input', type: 'text', spellcheck: 'false', autocomplete: 'off', 'aria-label': 'Controller C(s)' });
    cInput.value = cfg.C0;
    const cErr = el('div', { class: 'cs-err', role: 'alert', hidden: '' });
    const cBox = el('div', { class: 'cs-tf cs-tf-c' });
    const badge = el('span', { class: 'cs-badge' });
    const poleCv = el('canvas', { class: 'cs-poles', 'aria-label': 'closed-loop poles in the s-plane' });
    const poleList = el('div', { class: 'cs-polelist' });
    const form = el('form', { class: 'cs-cform', onsubmit: e => { e.preventDefault(); apply(); } }, [
      el('label', { for: 'c-input', class: 'cs-lhs', text: 'C(s) =' }), cInput,
      el('button', { type: 'submit', class: 'cs-btn cs-primary' }, ['Apply'])]);
    self.sections = [
      el('section', { class: 'cs-sec' }, [el('h2', { text: 'Plant' }), gBox, el('p', { class: 'cs-note', text: cfg.G.text })]),
      el('section', { class: 'cs-sec' }, [
        el('h2', { text: 'Controller' }), form, cErr,
        el('p', { class: 'cs-note', text: 'Simulating:' }), cBox,
        el('p', { class: 'cs-note', text: cfg.loopText || 'The controller sees the error e = r − y and outputs u = C(s) e.' })]),
      el('section', { class: 'cs-sec' }, [
        el('h2', {}, ['Closed-loop poles ', badge]), poleCv, poleList,
        el('p', { class: 'cs-note', text: 'Roots of 1 + C(s)G(s) = 0 for the linear model G(s). The simulation itself uses the nonlinear plant with saturation.' })])
    ];
    let qctx = null;
    self.mount = () => { qctx = setupCanvas(poleCv); };

    function setController(str) {
      const c = parseC(str);
      const ss = tf2ss(c.num, c.den);
      const a = convDesc(ss.den, cfg.G.den), b = convDesc(ss.num, cfg.G.num);   // ss.num, ss.den: same scaling
      const n = Math.max(a.length, b.length);
      const pad = p => new Array(n - p.length).fill(0).concat(p);
      const A2 = pad(a), B2 = pad(b);
      ss.poles = roots(A2.map((v, k) => v + B2[k]));
      ss.text = tfParts(c.num, c.den);
      self.ctrl = ss;
    }
    function show() {
      const ctrl = self.ctrl;
      cBox.replaceChildren(fracEl(ctrl.text));
      if (ctrl.nExtra) cBox.append(el('span', { class: 'cs-extra', text: ' × 1/(s/100+1)' + (ctrl.nExtra > 1 ? sup(ctrl.nExtra) : '') }));
      const maxRe = Math.max(-Infinity, ...ctrl.poles.map(p => p[0]));
      const stable = ctrl.poles.length === 0 || maxRe < -1e-9;
      const marginal = !stable && maxRe < 1e-9;
      badge.textContent = stable ? 'stable' : marginal ? 'marginal' : 'unstable';
      badge.className = 'cs-badge ' + (stable ? 'ok' : marginal ? 'warn' : 'bad');
      const shown = ctrl.poles.filter(p => p[1] >= 0).sort((p, q) => q[0] - p[0]);
      poleList.textContent = shown.map(([re, im]) => im ? fmt(re) + ' ± ' + fmt(im) + 'j' : fmt(re)).join(',   ');
    }
    function apply() {
      try { setController(cInput.value); } catch (err) {
        cErr.textContent = err.message + ' The previous C(s) is still in use.';
        cErr.hidden = false;
        return;
      }
      cErr.hidden = true;
      show();
      onApply();
    }
    self.drawPoles = colors => {
      const ctrl = self.ctrl, W = poleCv.width, Hh = poleCv.height, ctx = qctx;
      ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, W, Hh); ctx.scale(dpr(), dpr());
      const w = W / dpr(), h = Hh / dpr(), cx = w * 0.62, cy = h / 2;
      const m = Math.max(1, ...ctrl.poles.map(p => Math.max(Math.abs(p[0]), Math.abs(p[1])))) * 1.15;
      const sc = Math.min(cx, w - cx, cy) / m;
      ctx.fillStyle = colors.unstableBg; ctx.fillRect(cx, 0, w - cx, h);
      ctx.strokeStyle = colors.grid; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(0, cy); ctx.lineTo(w, cy); ctx.moveTo(cx, 0); ctx.lineTo(cx, h); ctx.stroke();
      ctx.font = '10px ' + colors.mono; ctx.fillStyle = colors.muted; ctx.textBaseline = 'top'; ctx.textAlign = 'left';
      ctx.fillText('Re', w - 18, cy + 3); ctx.fillText('Im', cx + 4, 2);
      ctx.fillText('axes ±' + fmt(m), 4, 2);
      ctx.strokeStyle = colors.pole; ctx.lineWidth = 2;
      ctrl.poles.forEach(([re, im]) => {
        const px = cx + re * sc, py = cy - im * sc, s = 4.5;
        ctx.beginPath(); ctx.moveTo(px - s, py - s); ctx.lineTo(px + s, py + s); ctx.moveTo(px + s, py - s); ctx.lineTo(px - s, py + s); ctx.stroke();
      });
    };
    try { setController(cfg.C0); } catch (err) { setController('1'); }
    show();
    return self;
  }

  function niceTicks(lo, hi, n) {
    const span = hi - lo, raw = span / n, mag = Math.pow(10, Math.floor(Math.log10(raw)));
    const stepv = [1, 2, 5, 10].map(m => m * mag).find(s => span / s <= n) || 10 * mag;
    const out = [];
    for (let v = Math.ceil(lo / stepv) * stepv; v <= hi + 1e-9; v += stepv) out.push(Math.abs(v) < 1e-12 ? 0 : v);
    return out;
  }

  // Time plot of several traces [{t, v, color, dash, width, label}] on a canvas.
  function drawTimePlot(cv, ctx, o, colors) {
    const W = cv.width, Hh = cv.height;
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, W, Hh); ctx.scale(dpr(), dpr());
    const w = W / dpr(), h = Hh / dpr();
    const L = 56, Rm = 12, T = 12, B = 30;
    const [t0, t1] = o.tLim;
    let lo = Infinity, hi = -Infinity;
    if (o.yLim) [lo, hi] = o.yLim;
    else {
      o.traces.forEach(tr => tr.v.forEach(v => { if (Number.isFinite(v)) { lo = Math.min(lo, v); hi = Math.max(hi, v); } }));
      if (!(hi > lo)) { lo = (Number.isFinite(lo) ? lo : 0) - 1; hi = lo + 2; }
      const pad = 0.1 * (hi - lo); lo -= pad; hi += pad;
    }
    const X = tt => L + (tt - t0) / (t1 - t0) * (w - L - Rm);
    const Y = v => T + (hi - v) / (hi - lo) * (h - T - B);
    ctx.font = '11px ' + colors.mono; ctx.fillStyle = colors.muted; ctx.strokeStyle = colors.grid; ctx.lineWidth = 1;
    ctx.textAlign = 'right'; ctx.textBaseline = 'middle';
    niceTicks(lo, hi, 5).forEach(v => { ctx.beginPath(); ctx.moveTo(L, Y(v)); ctx.lineTo(w - Rm, Y(v)); ctx.stroke(); ctx.fillText(fmt(v), L - 6, Y(v)); });
    ctx.textAlign = 'center'; ctx.textBaseline = 'top';
    niceTicks(t0, t1, 6).forEach(v => { if (v < t0 - 1e-9) return; ctx.beginPath(); ctx.moveTo(X(v), T); ctx.lineTo(X(v), h - B); ctx.stroke(); ctx.fillText(fmt(v), X(v), h - B + 5); });
    ctx.textAlign = 'right'; ctx.fillText('time [s]', w - Rm, h - 13);
    ctx.save(); ctx.translate(12, T + (h - T - B) / 2); ctx.rotate(-Math.PI / 2);
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(o.yLabel, 0, 0); ctx.restore();
    ctx.save(); ctx.beginPath(); ctx.rect(L, T, w - L - Rm, h - T - B); ctx.clip();
    o.traces.forEach(tr => {
      ctx.strokeStyle = tr.color; ctx.lineWidth = tr.width || 2; ctx.setLineDash(tr.dash || []); ctx.beginPath();
      let pen = false;
      tr.t.forEach((tt, k) => {
        const v = tr.v[k];
        if (!Number.isFinite(v) || !Number.isFinite(tt)) { pen = false; return; }
        pen ? ctx.lineTo(X(tt), Y(v)) : ctx.moveTo(X(tt), Y(v)); pen = true;
      });
      ctx.stroke(); ctx.setLineDash([]);
    });
    if (o.overlay) o.overlay(ctx, X, Y);
    ctx.restore();
    // legend, top right
    ctx.font = '12px ' + colors.body; ctx.textBaseline = 'middle'; ctx.textAlign = 'left';
    let lx = w - Rm - 8;
    const items = o.traces.filter(tr => tr.label).reverse();
    items.forEach(tr => {
      const tw = ctx.measureText(tr.label).width;
      lx -= tw + 28;
      ctx.strokeStyle = tr.color; ctx.lineWidth = tr.width || 2; ctx.setLineDash(tr.dash || []);
      ctx.beginPath(); ctx.moveTo(lx, T + 10); ctx.lineTo(lx + 18, T + 10); ctx.stroke(); ctx.setLineDash([]);
      ctx.fillStyle = colors.muted; ctx.fillText(tr.label, lx + 23, T + 10);
      lx -= 10;
    });
  }

  function isTyping(e) {
    const t = e.target;
    return t instanceof HTMLInputElement || t instanceof HTMLSelectElement || t instanceof HTMLTextAreaElement || e.metaKey || e.ctrlKey || e.altKey;
  }
  function speedSelect(options, value, onchange) {
    const s = el('select', { id: 'speed', class: 'cs-select', 'aria-label': 'Simulation speed', onchange: e => onchange(+e.target.value) },
      options.map(v => el('option', { value: v, text: v === 1 ? '1× real time' : v + '×' })));
    s.value = String(value);
    return s;
  }

  // ---------------------------------------------------------------------
  // Tracking demos: the output follows a reference that changes in time.
  // Port of the engine of DCM, CAR, CS, IP, MSD, PEN, SAT, TM and WT.
  // ---------------------------------------------------------------------
  function run(cfg) {
    const root = document.getElementById(cfg.mount || 'app');
    const NH = 1000;                       // samples in the plot window

    let x = cfg.x0.slice(), xc = [], t = 0, r = cfg.r(0), u = 0;
    let d = 0, dUntil = -1, paused = false, stopped = false, speed = 1, dt = 1e-3;
    let hist = { t: [], y: [], r: [] };

    const sceneCv = el('canvas', { class: 'cs-scene', 'aria-label': cfg.sceneLabel || 'animation' });
    const plotCv = el('canvas', { class: 'cs-plot', 'aria-label': 'output and reference vs time' });
    const msg = el('div', { class: 'cs-msg', role: 'status' });
    const tLbl = el('span', { class: 'cs-time', text: 't = 0.0 s' });
    const btnPause = el('button', { type: 'button', class: 'cs-btn', onclick: () => togglePause() }, ['Pause']);
    const cp = controllerPanel(cfg, () => reset());

    const panel = el('aside', { class: 'cs-panel' }, cp.sections.concat([
      el('section', { class: 'cs-sec' }, [
        el('h2', { text: 'Disturbance' }),
        el('div', { class: 'cs-row' }, [
          el('button', { type: 'button', class: 'cs-btn', onclick: () => doPush(-1) }, [cfg.pushNames[0]]),
          el('button', { type: 'button', class: 'cs-btn', onclick: () => doPush(1) }, [cfg.pushNames[1]])]),
        el('p', { class: 'cs-note', text: 'Keys: ← / → disturbance, R reset, Space pause.' })]),
      el('section', { class: 'cs-sec' }, [
        el('h2', { text: 'Run' }),
        el('div', { class: 'cs-row' }, [
          el('button', { type: 'button', class: 'cs-btn', onclick: () => reset() }, ['Reset']), btnPause,
          speedSelect([0.25, 0.5, 1, 2, 5, 10], 1, setSpeed)]),
        tLbl])
    ]));
    const main = el('div', { class: 'cs-main' }, [
      el('div', { class: 'cs-stage' }, [sceneCv, msg]), el('div', { class: 'cs-plotwrap' }, [plotCv])]);
    root.append(el('div', { class: 'cs-grid' }, [main, panel]));
    const sctx = setupCanvas(sceneCv), pctx = setupCanvas(plotCv);
    cp.mount();

    function deriv(x, xc) {
      const ctrl = cp.ctrl, e = r - cfg.y(x);
      let uc = ctrl.D * e;
      for (let i = 0; i < ctrl.n; i++) uc += ctrl.C[i] * xc[i];
      const us = Math.min(Math.max(uc, cfg.uLim[0]), cfg.uLim[1]);
      const dxc = ctrl.A.map((row, i) => row.reduce((s, a, j) => s + a * xc[j], 0) + ctrl.B[i] * e);
      return [cfg.plant(x, us + d), dxc, us];
    }
    const axpy = (v, h, k) => v.map((vi, i) => vi + h * k[i]);
    function step(h) {
      if (t >= dUntil) d = 0;
      r = cfg.r(t);
      const [k1, c1] = deriv(x, xc);
      const [k2, c2] = deriv(axpy(x, h / 2, k1), axpy(xc, h / 2, c1));
      const [k3, c3] = deriv(axpy(x, h / 2, k2), axpy(xc, h / 2, c2));
      const [k4, c4] = deriv(axpy(x, h, k3), axpy(xc, h, c3));
      x = x.map((v, i) => v + h / 6 * (k1[i] + 2 * k2[i] + 2 * k3[i] + k4[i]));
      xc = xc.map((v, i) => v + h / 6 * (c1[i] + 2 * c2[i] + 2 * c3[i] + c4[i]));
      t += h;
      u = deriv(x, xc)[2];
      if (!x.every(Number.isFinite) || (cfg.failed && cfg.failed(x))) stopped = true;
    }
    function reset() {
      x = cfg.x0.slice(); xc = new Array(cp.ctrl.n).fill(0); t = 0; r = cfg.r(0); u = 0;
      d = 0; dUntil = -1; stopped = false;
      hist = { t: [], y: [], r: [] };
      if (cfg.onReset) cfg.onReset();
    }
    function doPush(dir) { d = dir * cfg.push; dUntil = t + cfg.pushTime; }
    function togglePause() { paused = !paused; btnPause.textContent = paused ? 'Resume' : 'Pause'; }
    function setSpeed(v) { speed = v; dt = 1e-3 * Math.max(1, speed / 2); }

    document.addEventListener('keydown', e => {
      if (isTyping(e)) return;
      if (e.key === 'ArrowLeft') doPush(-1);
      else if (e.key === 'ArrowRight') doPush(1);
      else if (e.key === 'r' || e.key === 'R') reset();
      else if (e.key === ' ') { e.preventDefault(); togglePause(); }
    });

    reset();
    const win = cfg.window || 10;
    let last = performance.now(), carry = 0, sample = 0;
    function frame(now) {
      const wall = Math.min((now - last) / 1000, 0.05);
      last = now;
      if (!(paused || stopped)) {
        carry += wall * speed;
        while (carry >= dt && !stopped) {
          step(dt); carry -= dt; sample += dt;
          if (sample >= win / NH) {
            sample = 0;
            hist.t.push(t); hist.y.push(cfg.y(x) * cfg.yScale); hist.r.push(r * cfg.yScale);
            if (hist.t.length > NH) { hist.t.shift(); hist.y.shift(); hist.r.shift(); }
          }
        }
      } else carry = 0;
      const colors = colorsNow();
      const state = { x, r, d, u, t, colors };
      const b = typeof cfg.bounds === 'function' ? cfg.bounds(state) : cfg.bounds;
      drawWorld(sceneCv, sctx, b, cfg.drawScene, state);
      const t1 = Math.max(win, t);
      drawTimePlot(plotCv, pctx, {
        tLim: [t1 - win, t1], yLabel: cfg.yLabel,
        traces: [{ t: hist.t, v: hist.r, color: colors.ref, dash: [6, 4], width: 1.5, label: 'reference r' },
                 { t: hist.t, v: hist.y, color: colors.out, width: 2, label: 'output y' }]
      }, colors);
      cp.drawPoles(colors);
      msg.textContent = stopped ? (cfg.failText || 'The simulation diverged.') + '  Press R to reset.'
        : paused ? 'Paused' : d !== 0 ? 'Disturbance!' : '';
      tLbl.textContent = 't = ' + t.toFixed(1) + ' s';
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  }

  // ---------------------------------------------------------------------
  // Human vs controller demos (BOP, HA, IPC): first you balance it yourself
  // (keyboard, mouse or gamepad), then you hand it to C(s); in Controller
  // mode your input is a disturbance.
  // cfg: nAxes, z0(), plant(z, u), error(z, axis, g), combine(uc, human, mode),
  //      humanMax, failed(Z), score(g) -> {now, metric}, bestText(best),
  //      onStep(g, Z, h), onReset(g), bounds, drawScene, G, C0
  // ---------------------------------------------------------------------
  function runGame(cfg) {
    const root = document.getElementById(cfg.mount || 'app');
    const nA = cfg.nAxes || 1;
    let Z = [], ZC = [], U = new Array(nA).fill(0);
    let mode = 'human', paused = false, fallen = false, speed = 1;
    const dt = 1e-3, g = { tUp: 0, best: 0 };
    let keys = { x: 0, y: 0 }, mouse = { on: false, v: [0, 0] }, pad = { ok: false, v: [0, 0], buttons: [] }, human = new Array(nA).fill(0);

    const sceneCv = el('canvas', { class: 'cs-scene cs-game', 'aria-label': cfg.sceneLabel || 'animation' });
    const msg = el('div', { class: 'cs-msg', role: 'status' });
    const btnHuman = el('button', { type: 'button', class: 'cs-btn cs-toggle', 'aria-pressed': 'true', onclick: () => setMode('human') }, ['Human  (H)']);
    const btnCtrl = el('button', { type: 'button', class: 'cs-btn cs-toggle', 'aria-pressed': 'false', onclick: () => setMode('controller') }, ['Controller  (C)']);
    const inputSel = el('select', { id: 'input-dev', class: 'cs-select', 'aria-label': 'Input device' },
      ['Auto', 'Gamepad', 'Mouse', 'Keyboard'].map(v => el('option', { value: v, text: v })));
    const btnPause = el('button', { type: 'button', class: 'cs-btn', onclick: () => togglePause() }, ['Pause']);
    const lblNow = el('div', { class: 'cs-score' }), lblBest = el('div', { class: 'cs-score' });
    const lblPad = el('p', { class: 'cs-note', text: 'Gamepad: press any button so the browser detects it.' });
    const cp = controllerPanel(cfg, () => { reset(); setMode('controller'); });

    const panel = el('aside', { class: 'cs-panel' }, [
      el('section', { class: 'cs-sec' }, [
        el('h2', { text: 'Who is in control?' }),
        el('div', { class: 'cs-row' }, [btnHuman, btnCtrl]),
        lblNow, lblBest]),
      ...cp.sections,
      el('section', { class: 'cs-sec' }, [
        el('h2', { text: 'Input' }), inputSel,
        el('p', { class: 'cs-note', text: cfg.helpText }), lblPad]),
      el('section', { class: 'cs-sec' }, [
        el('h2', { text: 'Run' }),
        el('div', { class: 'cs-row' }, [
          el('button', { type: 'button', class: 'cs-btn', onclick: () => reset() }, ['Reset']), btnPause,
          speedSelect([0.25, 0.5, 1], 1, v => { speed = v; })]),
        el('p', { class: 'cs-note', text: 'Keys: H human, C controller, R reset, Space pause. Gamepad: button 1 switches, button 2 resets.' })])
    ]);
    root.append(el('div', { class: 'cs-grid' }, [el('div', { class: 'cs-main' }, [el('div', { class: 'cs-stage' }, [sceneCv, msg])]), panel]));
    const sctx = setupCanvas(sceneCv);
    cp.mount();

    function reset() {
      Z = []; ZC = [];
      for (let a = 0; a < nA; a++) { Z.push(cfg.z0(a)); ZC.push(new Array(cp.ctrl.n).fill(0)); }
      fallen = false; g.tUp = 0;
      if (cfg.onReset) cfg.onReset(g);
    }
    function setMode(m) {
      if (mode === 'human' && !fallen && g.tUp > 0) g.best = Math.max(g.best, cfg.score(g).metric);
      mode = m;
      btnHuman.setAttribute('aria-pressed', String(m === 'human'));
      btnCtrl.setAttribute('aria-pressed', String(m === 'controller'));
      ZC = ZC.map(() => new Array(cp.ctrl.n).fill(0));   // start the controller from rest
      g.tUp = 0;
      if (cfg.onReset) cfg.onReset(g, true);
    }
    function togglePause() { paused = !paused; btnPause.textContent = paused ? 'Resume' : 'Pause'; }

    function deriv(z, zc, hum, a) {
      const ctrl = cp.ctrl;
      let dzc, u;
      if (mode === 'controller') {
        const e = cfg.error(z, a, g);
        let uc = ctrl.D * e;
        for (let i = 0; i < ctrl.n; i++) uc += ctrl.C[i] * zc[i];
        dzc = ctrl.A.map((row, i) => row.reduce((s, v, j) => s + v * zc[j], 0) + ctrl.B[i] * e);
        u = cfg.combine(uc, hum, 'controller');
      } else {
        dzc = new Array(ctrl.n).fill(0);
        u = cfg.combine(0, hum, 'human');
      }
      return [cfg.plant(z, u), dzc, u];
    }
    const axpy = (v, h, k) => v.map((vi, i) => vi + h * k[i]);
    function step(h) {
      for (let a = 0; a < nA; a++) {
        const z = Z[a], zc = ZC[a], hum = human[a];
        const [k1, c1] = deriv(z, zc, hum, a);
        const [k2, c2] = deriv(axpy(z, h / 2, k1), axpy(zc, h / 2, c1), hum, a);
        const [k3, c3] = deriv(axpy(z, h / 2, k2), axpy(zc, h / 2, c2), hum, a);
        const [k4, c4] = deriv(axpy(z, h, k3), axpy(zc, h, c3), hum, a);
        Z[a] = z.map((v, i) => v + h / 6 * (k1[i] + 2 * k2[i] + 2 * k3[i] + k4[i]));
        ZC[a] = zc.map((v, i) => v + h / 6 * (c1[i] + 2 * c2[i] + 2 * c3[i] + c4[i]));
        U[a] = deriv(Z[a], ZC[a], hum, a)[2];
      }
      g.tUp += h;
      if (cfg.onStep) cfg.onStep(g, Z, h);
      if (cfg.failed(Z) || !Z.every(z => z.every(Number.isFinite))) {
        fallen = true;
        if (mode === 'human') g.best = Math.max(g.best, cfg.score(g).metric);
      }
    }

    // ---- inputs ----
    document.addEventListener('keydown', e => {
      if (isTyping(e)) return;
      const k = e.key;
      if (k === 'ArrowLeft') keys.x = -1;
      else if (k === 'ArrowRight') keys.x = 1;
      else if (k === 'ArrowUp' && nA > 1) keys.y = 1;
      else if (k === 'ArrowDown' && nA > 1) keys.y = -1;
      else if (k === 'h' || k === 'H') setMode('human');
      else if (k === 'c' || k === 'C') setMode('controller');
      else if (k === 'r' || k === 'R') reset();
      else if (k === ' ') togglePause();
      else return;
      e.preventDefault();
    });
    document.addEventListener('keyup', e => {
      if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') keys.x = 0;
      if (e.key === 'ArrowUp' || e.key === 'ArrowDown') keys.y = 0;
    });
    const mousePos = e => {
      const r = sceneCv.getBoundingClientRect();
      const vx = (e.clientX - r.left - r.width / 2) / (r.width / 2), vy = -(e.clientY - r.top - r.height / 2) / (r.height / 2);
      const k = nA > 1 ? 1.5 : 1;
      mouse.v = [Math.max(-1, Math.min(1, vx * k)), Math.max(-1, Math.min(1, vy * k))];
    };
    sceneCv.addEventListener('pointerdown', e => { mouse.on = true; sceneCv.setPointerCapture(e.pointerId); mousePos(e); });
    sceneCv.addEventListener('pointermove', e => { if (mouse.on) mousePos(e); });
    const up = () => { mouse.on = false; };
    sceneCv.addEventListener('pointerup', up); sceneCv.addEventListener('pointercancel', up);

    function readPad() {
      let p = null;
      try { p = Array.from(navigator.getGamepads ? navigator.getGamepads() : []).find(q => q && q.connected); } catch (err) { p = null; }
      if (!p) { pad.ok = false; return; }
      if (!pad.ok) lblPad.textContent = 'Gamepad: ' + p.id;
      pad.ok = true;
      const dz = v => Math.abs(v) < 0.08 ? 0 : v;
      pad.v = [dz(p.axes[0] || 0), -dz(p.axes[1] || 0)];
      const b = p.buttons.map(q => q.pressed);
      if (b[0] && !pad.buttons[0]) setMode(mode === 'human' ? 'controller' : 'human');
      if (b[1] && !pad.buttons[1]) reset();
      pad.buttons = b;
    }
    function humanInput() {
      const src = inputSel.value;
      let v = [0, 0];
      if (src === 'Gamepad') v = pad.v;
      else if (src === 'Mouse') v = mouse.on ? mouse.v : [0, 0];
      else if (src === 'Keyboard') v = [keys.x, keys.y];
      else if (keys.x || keys.y) v = [keys.x, keys.y];
      else if (mouse.on) v = mouse.v;
      else if (pad.ok) v = pad.v;
      return v.slice(0, nA).map(q => cfg.humanMax * Math.max(-1, Math.min(1, q)));
    }

    reset();
    let last = performance.now(), carry = 0;
    function frame(now) {
      const wall = Math.min((now - last) / 1000, 0.1);
      last = now;
      readPad();
      human = humanInput();
      if (!(paused || fallen)) {
        carry += wall * speed;
        while (carry >= dt && !fallen) { step(dt); carry -= dt; }
      } else carry = 0;
      const colors = colorsNow();
      const state = { Z, U, human, mode, g, colors, fallen };
      const b = typeof cfg.bounds === 'function' ? cfg.bounds(state) : cfg.bounds;
      drawWorld(sceneCv, sctx, b, cfg.drawScene, state);
      cp.drawPoles(colors);
      const sc = cfg.score(g);
      lblNow.textContent = sc.now;
      lblBest.textContent = cfg.bestText(g.best);
      msg.textContent = fallen ? (cfg.failText(g, mode) + '  Press R') : paused ? 'Paused'
        : mode === 'controller' && human.some(v => v !== 0) ? 'Disturbance!' : '';
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  }

  window.ControlSim = { run, runGame, parseC, tf2ss, roots, tfParts, fmt, el, setupCanvas, drawWorld, drawTimePlot, colorsNow, niceTicks, isTyping, speedSelect, dpr };
})();
