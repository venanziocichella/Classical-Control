/* fr.js - engine of the frequency response demos (port of FR_*_Demo.m).
 * Needs engine.js (ControlSim helpers). A page calls FreqSim.run(cfg) with
 * the model and the animation; this file does the sinusoidal input, the exact
 * (ZOH) simulation, the time plot with the measured shift, and the Bode plot.
 */
(function () {
  'use strict';
  const CS = window.ControlSim, el = CS.el, fmt = CS.fmt;

  // ---- small linear algebra (state dimension 1 or 2) ----
  const matmul = (A, B) => A.map(r => B[0].map((_, j) => r.reduce((s, a, k) => s + a * B[k][j], 0)));
  const matadd = (A, B, c = 1) => A.map((r, i) => r.map((a, j) => a + c * B[i][j]));
  const eye = n => Array.from({ length: n }, (_, i) => Array.from({ length: n }, (_, j) => +(i === j)));
  function expm(M) {
    // scaling and squaring with a Taylor series (small, well scaled matrices)
    const n = M.length, nrm = Math.max(...M.map(r => r.reduce((s, a) => s + Math.abs(a), 0)));
    const sq = Math.max(0, Math.ceil(Math.log2(nrm || 1)) + 1);
    const As = M.map(r => r.map(a => a / 2 ** sq));
    let E = eye(n), T = eye(n);
    for (let k = 1; k <= 16; k++) { T = matmul(T, As).map(r => r.map(a => a / k)); E = matadd(E, T); }
    for (let k = 0; k < sq; k++) E = matmul(E, E);
    return E;
  }
  // exact ZOH discretization of x' = A x + B u
  function c2d(A, B, h) {
    const n = A.length, M = [];
    for (let i = 0; i <= n; i++) M.push(Array.from({ length: n + 1 }, (_, j) => i < n ? (j < n ? A[i][j] * h : B[i] * h) : 0));
    const E = expm(M);
    return { Ad: E.slice(0, n).map(r => r.slice(0, n)), Bd: E.slice(0, n).map(r => r[n]) };
  }
  // G(jw) from descending polynomials
  function freqresp(num, den, w) {
    const ev = p => p.reduce(([re, im], a) => [re * 0 - im * w + a, re * w + im * 0], [0, 0]);
    const [nr, ni] = ev(num), [dr, di] = ev(den), m = dr * dr + di * di;
    return [(nr * dr + ni * di) / m, (ni * dr - nr * di) / m];
  }
  const wrap = v => ((v + 270) % 360 + 360) % 360 - 270;   // degrees in (-270, 90]
  // 3x3 least squares: fit a sin + b cos + c
  function fit3(ts, ys, w) {
    const N = [[0, 0, 0], [0, 0, 0], [0, 0, 0]], r = [0, 0, 0];
    ts.forEach((t, k) => {
      const f = [Math.sin(w * t), Math.cos(w * t), 1];
      for (let i = 0; i < 3; i++) { r[i] += f[i] * ys[k]; for (let j = 0; j < 3; j++) N[i][j] += f[i] * f[j]; }
    });
    for (let i = 0; i < 3; i++) {   // Gaussian elimination
      for (let k = i + 1; k < 3; k++) {
        const f = N[k][i] / N[i][i];
        for (let j = i; j < 3; j++) N[k][j] -= f * N[i][j];
        r[k] -= f * r[i];
      }
    }
    const x = [0, 0, 0];
    for (let i = 2; i >= 0; i--) { let s = r[i]; for (let j = i + 1; j < 3; j++) s -= N[i][j] * x[j]; x[i] = s / N[i][i]; }
    return x;
  }

  function run(cfg) {
    const root = document.getElementById(cfg.mount || 'app');
    let M = cfg.model(cfg.p0), w = cfg.w0, Amp = cfg.A0, p = cfg.p0, speed = 1, paused = false;
    let x = new Array(M.A.length).fill(0), t = 0, ph = 0, u = 0, y = 0, tChange = 0, h = 1e-3, D = null;
    const NH = 6000; let hist = { t: [], u: [], y: [] }, dec = 1, cnt = 0;

    // ---- DOM ----
    const sceneCv = el('canvas', { 'aria-label': cfg.sceneLabel || 'animation' });
    const timeCv = el('canvas', { 'aria-label': 'input and output vs time' });
    const magCv = el('canvas', { 'aria-label': 'Bode magnitude' });
    const phCv = el('canvas', { 'aria-label': 'Bode phase' });
    const msg = el('div', { class: 'cs-msg', role: 'status' });
    const lg = v => Math.log10(v);
    const slW = el('input', { id: 'freq', class: 'cs-range', type: 'range', min: lg(cfg.wRange[0]), max: lg(cfg.wRange[1]), step: 0.001, 'aria-label': 'Input frequency' });
    slW.addEventListener('input', () => setW(10 ** +slW.value));
    const lblW = el('div', { class: 'fr-val' });
    const pre = el('div', { class: 'cs-row' }, [0.1, 1, 10].map(f => el('button', { type: 'button', class: 'cs-btn', onclick: () => setW(f * M.wc) }, [f + '×' + cfg.cornerSym])));
    const slA = el('input', { id: 'amp', class: 'cs-range', type: 'range', min: cfg.ARange[0], max: cfg.ARange[1], step: (cfg.ARange[1] - cfg.ARange[0]) / 200, value: cfg.A0, 'aria-label': 'Amplitude' });
    slA.addEventListener('input', () => { Amp = +slA.value; tChange = t; refresh(); });
    const lblA = el('div', { class: 'fr-val' });
    const slP = el('input', { id: 'param', class: 'cs-range', type: 'range', min: cfg.pRange[0], max: cfg.pRange[1], step: (cfg.pRange[1] - cfg.pRange[0]) / 400, value: cfg.p0, 'aria-label': cfg.pName });
    slP.addEventListener('input', () => setP(+slP.value));
    const lblP = el('div', { class: 'fr-val' });
    const gBox = el('div', { class: 'cs-tf' });
    const btnPause = el('button', { type: 'button', class: 'cs-btn', onclick: () => togglePause() }, ['Pause']);
    const verdict = el('div', { class: 'fr-verdict' });
    const lblTh = el('div', { class: 'fr-val' }), lblMeas = el('div', { class: 'fr-val' }), lblT = el('div', { class: 'cs-time' });

    const panel = el('aside', { class: 'cs-panel' }, [
      el('section', { class: 'cs-sec' }, [el('h2', { text: 'System' }), gBox, el('p', { class: 'cs-note', text: cfg.systemText })]),
      el('section', { class: 'cs-sec' }, [el('h2', { class: 'plain', text: 'Input  ' + cfg.uText + ' = A sin(ωt)' }), slW, lblW, pre,
        el('label', { for: 'amp', class: 'cs-note', text: 'Amplitude A ' + cfg.uUnit }), slA, lblA]),
      el('section', { class: 'cs-sec' }, [el('h2', { class: 'plain', text: cfg.pName }), slP, lblP]),
      el('section', { class: 'cs-sec' }, [verdict, lblTh, lblMeas]),
      el('section', { class: 'cs-sec' }, [el('h2', { text: 'Run' }),
        el('div', { class: 'cs-row' }, [btnPause, el('button', { type: 'button', class: 'cs-btn', onclick: () => reset() }, ['Reset']),
          CS.speedSelect([0.1, 0.25, 0.5, 1, 2, 5, 10], 1, v => { speed = v; })]),
        lblT, el('p', { class: 'cs-note', text: cfg.helpText + ' Keys: Space pause, R reset, ↑/↓ frequency.' })])
    ]);
    const card = (c, extra) => el('div', { class: 'fr-card' + (extra ? ' ' + extra : '') }, [c]);
    const stage = el('div', { class: 'fr-card cs-stage' }, [sceneCv, msg]);
    root.append(el('div', { class: 'fr-grid' }, [stage, card(magCv), panel, card(timeCv), card(phCv)]));
    const sctx = CS.setupCanvas(sceneCv), tctx = CS.setupCanvas(timeCv), mctx = CS.setupCanvas(magCv), pctx = CS.setupCanvas(phCv);

    // ---- model and simulation ----
    const winLen = () => Math.min(Math.max(4 * 2 * Math.PI / w, 2), 80);
    function rediscretize() {
      h = Math.min(2e-3, (2 * Math.PI / w) / 400);
      D = c2d(M.A, M.B, h);
      dec = Math.max(1, Math.round(winLen() / (NH * 0.8) / h));
    }
    function stepSim() {
      ph += w * h;                         // phase accumulator: no jump when w changes
      u = Amp * Math.sin(ph);
      x = D.Ad.map((r, i) => r.reduce((s, a, j) => s + a * x[j], 0) + D.Bd[i] * u);
      t += h;
      y = M.C.reduce((s, c, i) => s + c * x[i], 0) + M.D * u;
      if (++cnt >= dec) {
        cnt = 0;
        hist.t.push(t); hist.u.push(u); hist.y.push(y);
        if (hist.t.length > NH) { hist.t.shift(); hist.u.shift(); hist.y.shift(); }
      }
    }
    function setW(v) { w = Math.min(Math.max(v, cfg.wRange[0]), cfg.wRange[1]); slW.value = lg(w); tChange = t; rediscretize(); refresh(); }
    function setP(v) {
      p = v; M = cfg.model(p); tChange = t;
      if (x.length !== M.A.length) x = new Array(M.A.length).fill(0);
      rediscretize();
      gBox.replaceChildren(el('span', { class: 'cs-lhs', text: 'G(s) =' }), fracFrom(M.num, M.den));
      lblP.textContent = M.paramText;
      refresh();
    }
    function fracFrom(num, den) {
      const parts = CS.tfParts(num, den);
      return parts.den ? el('span', { class: 'cs-frac' }, [el('span', { class: 'cs-num', text: parts.num }), el('span', { class: 'cs-den', text: parts.den })])
        : el('span', { class: 'cs-poly', text: parts.num });
    }
    const Gjw = ww => freqresp(M.num, M.den, ww);
    function refresh() {
      const [re, im] = Gjw(w), mag = Math.hypot(re, im), phi = wrap(Math.atan2(im, re) * 180 / Math.PI);
      lblW.textContent = 'ω = ' + fmt(w) + ' rad/s   (f = ' + fmt(w / 2 / Math.PI) + ' Hz, period ' + fmt(2 * Math.PI / w) + ' s)';
      lblA.textContent = 'A = ' + fmt(Amp) + ' ' + cfg.uUnit.replace(/[()]/g, '');
      lblTh.textContent = 'Theory: |G(jω)| = ' + fmt(mag) + ' = ' + (20 * Math.log10(mag)).toFixed(1) + ' dB,  ∠G(jω) = ' + (phi >= 0 ? '+' : '') + phi.toFixed(1) + '°';
      if (mag > 1.02) { verdict.textContent = 'AMPLIFIED  ×' + fmt(mag); verdict.className = 'fr-verdict amp'; }
      else if (mag < 0.98) { verdict.textContent = 'ATTENUATED  ×' + fmt(mag); verdict.className = 'fr-verdict att'; }
      else { verdict.textContent = 'PASSES  ×1'; verdict.className = 'fr-verdict pass'; }
    }
    function reset() { x = new Array(M.A.length).fill(0); t = 0; ph = 0; tChange = 0; hist = { t: [], u: [], y: [] }; }
    function togglePause() { paused = !paused; btnPause.textContent = paused ? 'Play' : 'Pause'; }
    document.addEventListener('keydown', e => {
      if (CS.isTyping(e)) return;
      if (e.key === ' ') togglePause();
      else if (e.key === 'r' || e.key === 'R') reset();
      else if (e.key === 'ArrowUp') setW(w * 2 ** (1 / 3));
      else if (e.key === 'ArrowDown') setW(w / 2 ** (1 / 3));
      else return;
      e.preventDefault();
    });

    // steady-state measurement: least-squares sine fit over whole periods
    function measure() {
      const T = 2 * Math.PI / w;
      if (!(t - tChange > Math.max(M.settle, 0) + 2 * T)) return null;
      const sel = (a, b) => { const ts = [], us = [], ys = []; hist.t.forEach((tt, k) => { if (tt > a && tt <= b) { ts.push(tt); us.push(hist.u[k]); ys.push(hist.y[k]); } }); return [ts, us, ys]; };
      const one = (a, b) => {
        const [ts, us, ys] = sel(a, b);
        if (ts.length < 20) return null;
        const cu = fit3(ts, us, w), cy = fit3(ts, ys, w);
        return { ratio: Math.hypot(cy[0], cy[1]) / Math.hypot(cu[0], cu[1]), phi: wrap((Math.atan2(cy[1], cy[0]) - Math.atan2(cu[1], cu[0])) * 180 / Math.PI), cu };
      };
      const m1 = one(t - T, t), m2 = one(t - 2 * T, t - T);
      if (!m1 || !m2) return null;
      const settled = Math.abs(m1.ratio - m2.ratio) < 0.01 * m1.ratio + 1e-9 && Math.abs(((m1.phi - m2.phi + 180) % 360 + 360) % 360 - 180) < 1;
      return settled ? m1 : null;
    }

    // ---- Bode plot ----
    function drawBode(cv, ctx, which, colors) {
      const W = cv.width, H = cv.height, r = CS.dpr();
      ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, W, H); ctx.scale(r, r);
      const wd = W / r, ht = H / r, L = 56, Rm = 12, T = 28, B = which === 'mag' ? 22 : 34;
      const [w0, w1] = cfg.wRange, N = 400, ws = [], vs = [];
      let prev = null;
      for (let k = 0; k <= N; k++) {
        const ww = w0 * (w1 / w0) ** (k / N), [re, im] = Gjw(ww);
        let v;
        if (which === 'mag') v = 20 * Math.log10(Math.hypot(re, im));
        else { v = Math.atan2(im, re) * 180 / Math.PI; if (prev === null) v = wrap(v); else v += 360 * Math.round((prev - v) / 360); prev = v; }
        ws.push(ww); vs.push(v);
      }
      let lo, hi;
      if (which === 'mag') { lo = Math.max(Math.min(...vs) - 5, -60); hi = Math.max(Math.max(...vs) + 8, 10); }
      else { lo = Math.floor(Math.min(...vs) / 45) * 45 - 10; hi = Math.ceil(Math.max(...vs) / 45) * 45 + 10; }
      const X = ww => L + (Math.log10(ww) - Math.log10(w0)) / (Math.log10(w1) - Math.log10(w0)) * (wd - L - Rm);
      const Y = v => T + (hi - v) / (hi - lo) * (ht - T - B);
      ctx.font = '11px ' + colors.mono; ctx.lineWidth = 1;
      // decade grid
      for (let e = Math.floor(Math.log10(w0)); e <= Math.ceil(Math.log10(w1)); e++) {
        for (let m = 1; m < 10; m++) {
          const ww = m * 10 ** e; if (ww < w0 * 0.999 || ww > w1 * 1.001) continue;
          ctx.strokeStyle = colors.grid; ctx.globalAlpha = m === 1 ? 1 : 0.5;
          ctx.beginPath(); ctx.moveTo(X(ww), T); ctx.lineTo(X(ww), ht - B); ctx.stroke(); ctx.globalAlpha = 1;
          if (m === 1 && which !== 'mag') { ctx.fillStyle = colors.muted; ctx.textAlign = 'center'; ctx.textBaseline = 'top'; ctx.fillText(fmt(ww), X(ww), ht - B + 5); }
        }
      }
      const ticks = which === 'mag' ? CS.niceTicks(lo, hi, 5) : (() => { const o = []; for (let v = Math.ceil(lo / 45) * 45; v <= hi; v += 45) o.push(v); return o; })();
      ctx.textAlign = 'right'; ctx.textBaseline = 'middle';
      ticks.forEach(v => { ctx.strokeStyle = colors.grid; ctx.beginPath(); ctx.moveTo(L, Y(v)); ctx.lineTo(wd - Rm, Y(v)); ctx.stroke(); ctx.fillStyle = colors.muted; ctx.fillText(fmt(v), L - 6, Y(v)); });
      if (which === 'mag' && lo < 0 && hi > 0) { ctx.strokeStyle = colors.fg; ctx.beginPath(); ctx.moveTo(L, Y(0)); ctx.lineTo(wd - Rm, Y(0)); ctx.stroke(); }
      if (which !== 'mag') { ctx.fillStyle = colors.muted; ctx.textAlign = 'right'; ctx.textBaseline = 'top'; ctx.fillText('frequency ω [rad/s]', wd - Rm, ht - 14); }
      ctx.save(); ctx.translate(12, T + (ht - T - B) / 2); ctx.rotate(-Math.PI / 2);
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillStyle = colors.muted;
      ctx.fillText(which === 'mag' ? '|G(jω)| [dB]' : '∠G(jω) [deg]', 0, 0); ctx.restore();
      // corner
      ctx.strokeStyle = colors.muted; ctx.setLineDash([5, 4]); ctx.beginPath(); ctx.moveTo(X(M.wc), T); ctx.lineTo(X(M.wc), ht - B); ctx.stroke(); ctx.setLineDash([]);
      ctx.fillStyle = colors.muted; ctx.textAlign = 'left'; ctx.textBaseline = 'top'; ctx.fillText(cfg.cornerSym, X(M.wc) + 4, T + 2);
      // curve
      ctx.save(); ctx.beginPath(); ctx.rect(L, T, wd - L - Rm, ht - T - B); ctx.clip();
      ctx.strokeStyle = colors.out; ctx.lineWidth = 2.5; ctx.beginPath();
      ws.forEach((ww, k) => k ? ctx.lineTo(X(ww), Y(vs[k])) : ctx.moveTo(X(ww), Y(vs[k]))); ctx.stroke();
      // current frequency
      const [re, im] = Gjw(w);
      let v = which === 'mag' ? 20 * Math.log10(Math.hypot(re, im)) : Math.atan2(im, re) * 180 / Math.PI;
      if (which !== 'mag') { const i = Math.min(N, Math.max(0, Math.round(N * Math.log(w / w0) / Math.log(w1 / w0)))); v += 360 * Math.round((vs[i] - v) / 360); }
      ctx.fillStyle = colors.alert; ctx.strokeStyle = colors.panel; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(X(w), Y(v), 6, 0, 2 * Math.PI); ctx.fill(); ctx.stroke();
      ctx.restore();
      if (which === 'mag') {
        ctx.font = '600 13px ' + colors.body; ctx.fillStyle = colors.fg; ctx.textAlign = 'left'; ctx.textBaseline = 'top';
        ctx.fillText('Bode plot', L, 7);
        ctx.font = '12px ' + colors.body; ctx.fillStyle = colors.muted; ctx.textAlign = 'right';
        ctx.fillText(M.ampNote, wd - Rm, 8);
      }
    }

    // ---- loop ----
    setP(cfg.p0); setW(cfg.w0); refresh();
    let last = performance.now(), carry = 0;
    function frame(now) {
      const wall = Math.min((now - last) / 1000, 0.05); last = now;
      if (!paused) { carry += wall * speed; while (carry >= h) { stepSim(); carry -= h; } } else carry = 0;
      const colors = CS.colorsNow();
      CS.drawWorld(sceneCv, sctx, cfg.bounds, cfg.drawScene, { x, u, y, t, M, A: Amp, colors, ARange: cfg.ARange });
      const win = winLen(), t1 = Math.max(win, t);
      let yMax = Amp;
      hist.t.forEach((tt, k) => { if (tt > t - win) yMax = Math.max(yMax, Math.abs(hist.y[k])); });
      const m = measure();
      drawTimePlotFR(m, [t1 - win, t1], yMax, colors);
      CS.dpr();
      drawBode(magCv, mctx, 'mag', colors); drawBode(phCv, pctx, 'phase', colors);
      lblMeas.textContent = m ? 'Measured (simulation): ratio ' + fmt(m.ratio) + ', phase ' + (m.phi >= 0 ? '+' : '') + m.phi.toFixed(1) + '°'
        : 'Measured (simulation): settling… wait for the transient to die out.';
      lblT.textContent = 't = ' + t.toFixed(1) + ' s';
      msg.textContent = paused ? 'Paused' : '';
      requestAnimationFrame(frame);
    }
    function drawTimePlotFR(m, tLim, yMax, colors) {
      const T = 2 * Math.PI / w;
      let overlay = null;
      if (m) {
        const dt = -m.phi / 360 * T;   // output lags by dt (leads if < 0)
        const tPk = (Math.PI / 2 - Math.atan2(m.cu[1], m.cu[0])) / w;
        const nPk = Math.floor((t - tPk - Math.max(dt, 0) - 0.05 * T) / T);
        const ta = tPk + nPk * T, tb = ta + dt, yTop = 1.1 * yMax;
        overlay = (ctx, X, Y) => {
          ctx.strokeStyle = colors.alert; ctx.lineWidth = 1.2; ctx.beginPath();
          ctx.moveTo(X(ta), Y(-yMax)); ctx.lineTo(X(ta), Y(yTop)); ctx.moveTo(X(tb), Y(-yMax)); ctx.lineTo(X(tb), Y(yTop));
          ctx.moveTo(X(ta), Y(yTop)); ctx.lineTo(X(tb), Y(yTop)); ctx.stroke();
          ctx.fillStyle = colors.alert; ctx.font = '13px ' + colors.mono; ctx.textAlign = 'center'; ctx.textBaseline = 'bottom';
          ctx.fillText('Δt = ' + fmt(Math.abs(dt)) + ' s', X((ta + tb) / 2), Y(yTop) - 2);
        };
      }
      CS.drawTimePlot(timeCv, tctx, {
        tLim, yLabel: cfg.plotLabel, yLim: [-1.25 * yMax, 1.25 * yMax], overlay,
        traces: [{ t: hist.t, v: hist.u, color: colors.muted, width: 1.5, label: 'input ' + cfg.uSym },
                 { t: hist.t, v: hist.y, color: colors.out, width: 2, label: 'output ' + cfg.ySym }]
      }, colors);
    }
    requestAnimationFrame(frame);
  }

  window.FreqSim = { run, c2d, expm, freqresp };
})();
