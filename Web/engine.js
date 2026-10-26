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
    return z.map(([re, im]) => [re, Math.abs(im) < 1e-9 * rad ? 0 : im]);
  }

  // ---------------------------------------------------------------------
  // The page
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

  function setupCanvas(cv) {
    const ctx = cv.getContext('2d');
    const fit = () => {
      const r = cv.getBoundingClientRect(), dpr = window.devicePixelRatio || 1;
      cv.width = Math.max(1, Math.round(r.width * dpr));
      cv.height = Math.max(1, Math.round(r.height * dpr));
    };
    new ResizeObserver(fit).observe(cv);
    fit();
    return ctx;
  }

  function run(cfg) {
    const root = document.getElementById(cfg.mount || 'app');
    const H = Math.round(cfg.window / 1e-3 / 10);   // history samples

    // ---- state ----
    let ctrl = null, cText = cfg.C0;
    let x = cfg.x0.slice(), xc = [], t = 0, r = cfg.r(0), u = 0;
    let d = 0, dUntil = -1, paused = false, stopped = false, speed = 1, dt = 1e-3;
    let hist = { t: [], y: [], r: [] };

    // ---- DOM ----
    const sceneCv = el('canvas', { class: 'cs-scene', 'aria-label': cfg.sceneLabel || 'animation' });
    const plotCv = el('canvas', { class: 'cs-plot', 'aria-label': 'output and reference vs time' });
    const msg = el('div', { class: 'cs-msg', role: 'status' });
    const stage = el('div', { class: 'cs-stage' }, [sceneCv, msg]);
    const tLbl = el('span', { class: 'cs-time', text: 't = 0.0 s' });

    const gBox = el('div', { class: 'cs-tf' }, [el('span', { class: 'cs-lhs', text: 'G(s) =' }), fracEl(tfParts(cfg.G.num, cfg.G.den))]);
    const cInput = el('input', { id: 'c-input', class: 'cs-input', type: 'text', spellcheck: 'false', autocomplete: 'off', 'aria-label': 'Controller C(s)' });
    cInput.value = cfg.C0;
    const cErr = el('div', { class: 'cs-err', role: 'alert', hidden: '' });
    const cBox = el('div', { class: 'cs-tf cs-tf-c' });
    const badge = el('span', { class: 'cs-badge' });
    const poleCv = el('canvas', { class: 'cs-poles', 'aria-label': 'closed-loop poles in the s-plane' });
    const poleList = el('div', { class: 'cs-polelist' });

    const btnPause = el('button', { type: 'button', class: 'cs-btn', onclick: () => togglePause() }, ['Pause']);
    const speedSel = el('select', { id: 'speed', class: 'cs-select', 'aria-label': 'Simulation speed', onchange: e => setSpeed(+e.target.value) },
      [0.25, 0.5, 1, 2, 5, 10].map(v => el('option', { value: v, text: v === 1 ? '1× real time' : v + '×' })));
    speedSel.value = '1';

    const form = el('form', { class: 'cs-cform', onsubmit: e => { e.preventDefault(); apply(); } }, [
      el('label', { for: 'c-input', class: 'cs-lhs', text: 'C(s) =' }), cInput,
      el('button', { type: 'submit', class: 'cs-btn cs-primary' }, ['Apply'])]);

    const panel = el('aside', { class: 'cs-panel' }, [
      el('section', { class: 'cs-sec' }, [
        el('h2', { text: 'Plant' }), gBox,
        el('p', { class: 'cs-note', text: cfg.G.text })]),
      el('section', { class: 'cs-sec' }, [
        el('h2', { text: 'Controller' }), form, cErr,
        el('p', { class: 'cs-note', text: 'Simulating:' }), cBox,
        el('p', { class: 'cs-note', text: cfg.loopText || 'The controller sees the error e = r − y and outputs u = C(s) e.' })]),
      el('section', { class: 'cs-sec' }, [
        el('h2', {}, ['Closed-loop poles ', badge]), poleCv, poleList,
        el('p', { class: 'cs-note', text: 'Roots of 1 + C(s)G(s) = 0 for the linear model. The simulation itself uses the nonlinear plant with saturation.' })]),
      el('section', { class: 'cs-sec' }, [
        el('h2', { text: 'Disturbance' }),
        el('div', { class: 'cs-row' }, [
          el('button', { type: 'button', class: 'cs-btn', onclick: () => doPush(-1) }, [cfg.pushNames[0]]),
          el('button', { type: 'button', class: 'cs-btn', onclick: () => doPush(1) }, [cfg.pushNames[1]])]),
        el('p', { class: 'cs-note', text: 'Keys: ← / → disturbance, R reset, Space pause.' })]),
      el('section', { class: 'cs-sec' }, [
        el('h2', { text: 'Run' }),
        el('div', { class: 'cs-row' }, [
          el('button', { type: 'button', class: 'cs-btn', onclick: () => reset() }, ['Reset']), btnPause, speedSel]),
        tLbl])
    ]);
    const main = el('div', { class: 'cs-main' }, [stage, el('div', { class: 'cs-plotwrap' }, [plotCv])]);
    root.append(el('div', { class: 'cs-grid' }, [main, panel]));

    const sctx = setupCanvas(sceneCv), pctx = setupCanvas(plotCv), qctx = setupCanvas(poleCv);

    // ---- controller ----
    function setController(str) {
      const c = parseC(str);
      const ss = tf2ss(c.num, c.den);
      // closed-loop characteristic polynomial den_C den_G + num_C num_G
      const a = convDesc(ss.den, cfg.G.den), b = convDesc(stripLead(c.num), cfg.G.num);
      const n = Math.max(a.length, b.length);
      const pad = p => new Array(n - p.length).fill(0).concat(p);
      const A2 = pad(a), B2 = pad(b);
      ss.poles = roots(A2.map((v, k) => v + B2[k]));
      ss.text = tfParts(c.num, c.den);
      ctrl = ss;
      cText = str;
    }

    function showController() {
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
      try {
        setController(cInput.value);
      } catch (err) {
        cErr.textContent = err.message + ' The previous C(s) is still in use.';
        cErr.hidden = false;
        return;
      }
      cErr.hidden = true;
      showController();
      reset();
    }

    // ---- simulation ----
    function deriv(x, xc) {
      const e = r - cfg.y(x);
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
      x = cfg.x0.slice(); xc = new Array(ctrl.n).fill(0); t = 0; r = cfg.r(0); u = 0;
      d = 0; dUntil = -1; stopped = false;
      hist = { t: [], y: [], r: [] };
    }
    function doPush(dir) { d = dir * cfg.push; dUntil = t + cfg.pushTime; }
    function togglePause() { paused = !paused; btnPause.textContent = paused ? 'Resume' : 'Pause'; }
    function setSpeed(v) { speed = v; dt = 1e-3 * Math.max(1, speed / 2); }

    document.addEventListener('keydown', e => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLSelectElement || e.metaKey || e.ctrlKey) return;
      if (e.key === 'ArrowLeft') doPush(-1);
      else if (e.key === 'ArrowRight') doPush(1);
      else if (e.key === 'r' || e.key === 'R') reset();
      else if (e.key === ' ') { e.preventDefault(); togglePause(); }
      else return;
    });

    // ---- drawing ----
    function drawPlot(colors) {
      const W = plotCv.width, Hh = plotCv.height, dpr = window.devicePixelRatio || 1;
      const ctx = pctx;
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.clearRect(0, 0, W, Hh);
      ctx.scale(dpr, dpr);
      const w = W / dpr, h = Hh / dpr;
      const L = 52, Rm = 12, T = 12, B = 30;
      const t1 = Math.max(cfg.window, t), t0 = t1 - cfg.window;
      let lo = Infinity, hi = -Infinity;
      hist.y.concat(hist.r).forEach(v => { if (Number.isFinite(v)) { lo = Math.min(lo, v); hi = Math.max(hi, v); } });
      if (!(hi > lo)) { lo = (Number.isFinite(lo) ? lo : 0) - 1; hi = lo + 2; }
      const pad = 0.1 * (hi - lo); lo -= pad; hi += pad;
      const X = tt => L + (tt - t0) / (t1 - t0) * (w - L - Rm);
      const Y = v => T + (hi - v) / (hi - lo) * (h - T - B);
      // grid and ticks
      ctx.font = '11px ' + colors.mono;
      ctx.fillStyle = colors.muted; ctx.strokeStyle = colors.grid; ctx.lineWidth = 1;
      const yt = niceTicks(lo, hi, 5);
      ctx.textAlign = 'right'; ctx.textBaseline = 'middle';
      yt.forEach(v => { ctx.beginPath(); ctx.moveTo(L, Y(v)); ctx.lineTo(w - Rm, Y(v)); ctx.stroke(); ctx.fillText(fmt(v), L - 6, Y(v)); });
      ctx.textAlign = 'center'; ctx.textBaseline = 'top';
      niceTicks(t0, t1, 6).forEach(v => { if (v < t0 - 1e-9) return; ctx.beginPath(); ctx.moveTo(X(v), T); ctx.lineTo(X(v), h - B); ctx.stroke(); ctx.fillText(fmt(v), X(v), h - B + 5); });
      ctx.textAlign = 'right'; ctx.fillText('time [s]', w - Rm, h - 13);
      ctx.save(); ctx.translate(12, T + (h - T - B) / 2); ctx.rotate(-Math.PI / 2);
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(cfg.yLabel, 0, 0); ctx.restore();
      // traces
      ctx.save(); ctx.beginPath(); ctx.rect(L, T, w - L - Rm, h - T - B); ctx.clip();
      const line = (ys, color, dash, lw) => {
        ctx.strokeStyle = color; ctx.lineWidth = lw; ctx.setLineDash(dash); ctx.beginPath();
        hist.t.forEach((tt, k) => { const yy = Y(ys[k]); k ? ctx.lineTo(X(tt), yy) : ctx.moveTo(X(tt), yy); });
        ctx.stroke(); ctx.setLineDash([]);
      };
      line(hist.r, colors.ref, [6, 4], 1.5);
      line(hist.y, colors.out, [], 2);
      ctx.restore();
      // legend
      ctx.font = '12px ' + colors.body; ctx.textBaseline = 'middle'; ctx.textAlign = 'left';
      const lx = w - Rm - 150, ly = T + 10;
      ctx.strokeStyle = colors.ref; ctx.setLineDash([6, 4]); ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(lx, ly); ctx.lineTo(lx + 18, ly); ctx.stroke(); ctx.setLineDash([]);
      ctx.fillStyle = colors.muted; ctx.fillText('reference r', lx + 23, ly);
      ctx.strokeStyle = colors.out; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(lx + 85, ly); ctx.lineTo(lx + 103, ly); ctx.stroke();
      ctx.fillText('output y', lx + 108, ly);
    }

    function drawPoles(colors) {
      const W = poleCv.width, Hh = poleCv.height, dpr = window.devicePixelRatio || 1, ctx = qctx;
      ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, W, Hh); ctx.scale(dpr, dpr);
      const w = W / dpr, h = Hh / dpr, cx = w * 0.62, cy = h / 2;
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
    }

    function drawScene(colors) {
      const W = sceneCv.width, Hh = sceneCv.height, ctx = sctx;
      ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, W, Hh);
      const [x0, x1, y0, y1] = cfg.bounds;
      const s = Math.min(W / (x1 - x0), Hh / (y1 - y0));
      // world coordinates: y up, centered
      ctx.setTransform(s, 0, 0, -s, W / 2 - s * (x0 + x1) / 2, Hh / 2 + s * (y0 + y1) / 2);
      cfg.drawScene(ctx, { x, r, d, u, t, colors, px: 1 / s });
    }

    function colorsNow() {
      return {
        fg: token('--fg'), muted: token('--muted'), grid: token('--grid'), ref: token('--ref'), out: token('--out'),
        pole: token('--pole'), unstableBg: token('--unstable-bg'), part: token('--part'), metal: token('--metal'),
        panel: token('--panel'), alert: token('--alert'),
        mono: token('--font-mono'), body: token('--font-body')
      };
    }

    // ---- start ----
    try { setController(cfg.C0); } catch (err) { setController('1'); }
    showController();
    reset();

    let last = performance.now(), carry = 0, sample = 0;
    function frame(now) {
      const wall = Math.min((now - last) / 1000, 0.05);
      last = now;
      if (!(paused || stopped)) {
        carry += wall * speed;
        while (carry >= dt && !stopped) {
          step(dt); carry -= dt;
          sample += dt;
          if (sample >= cfg.window / H) {
            sample = 0;
            hist.t.push(t); hist.y.push(cfg.y(x) * cfg.yScale); hist.r.push(r * cfg.yScale);
            if (hist.t.length > H) { hist.t.shift(); hist.y.shift(); hist.r.shift(); }
          }
        }
      } else carry = 0;
      const colors = colorsNow();
      drawScene(colors); drawPlot(colors); drawPoles(colors);
      msg.textContent = stopped ? (cfg.failText || 'The simulation diverged.') + '  Press R to reset.'
        : paused ? 'Paused' : d !== 0 ? 'Disturbance!' : '';
      msg.className = 'cs-msg' + (stopped ? ' stop' : '');
      tLbl.textContent = 't = ' + t.toFixed(1) + ' s';
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  }

  function niceTicks(lo, hi, n) {
    const span = hi - lo, raw = span / n, mag = Math.pow(10, Math.floor(Math.log10(raw)));
    const stepv = [1, 2, 5, 10].map(m => m * mag).find(s => span / s <= n) || 10 * mag;
    const out = [];
    for (let v = Math.ceil(lo / stepv) * stepv; v <= hi + 1e-9; v += stepv) out.push(Math.abs(v) < 1e-12 ? 0 : v);
    return out;
  }

  window.ControlSim = { run, parseC, tf2ss, roots, tfParts };
})();
