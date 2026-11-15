/* rlocus.js - root locus animation of Chapter 6 (port of RL_Animation_Demo.m).
 * Needs engine.js (ControlSim: parser, roots, page helpers).
 *
 * The open loop is L(s) = K N(s)/D(s): the user types only N(s)/D(s), the gain
 * K is set with a slider (or typed). The s-plane shows the root locus (the
 * roots of D(s) + K N(s) = 0 for 0 <= K < inf), the open-loop poles (x) and
 * zeros (o), and the closed-loop poles for the current K (filled dots), which
 * move along the locus as K changes. Drag along the locus to pick K there.
 */
(function () {
  'use strict';
  const CS = window.ControlSim, el = CS.el, fmt = CS.fmt;
  const TAU = 2 * Math.PI;

  const cabs = a => Math.hypot(a[0], a[1]);
  const strip = p => { const k = p.findIndex(v => v !== 0); return k < 0 ? [0] : p.slice(k); };
  function charPoly(den, num, K) {   // den + K num, descending
    const n = Math.max(den.length, num.length), r = [];
    for (let i = 0; i < n; i++) r.push((den[i - n + den.length] || 0) + K * (num[i - n + num.length] || 0));
    return r;
  }
  function polyval(p, s) {   // descending real coefficients at complex s
    let re = 0, im = 0;
    for (const a of p) { const t = re * s[0] - im * s[1] + a; im = re * s[1] + im * s[0]; re = t; }
    return [re, im];
  }
  function fmtC(z) {
    const tol = 1e-9 * Math.max(1, cabs(z));
    const re = Math.abs(z[0]) < tol ? 0 : z[0], im = Math.abs(z[1]) < tol ? 0 : z[1];
    if (im === 0) return fmt(re).replace('-', '−');
    const ims = fmt(Math.abs(im)) + 'j';
    if (re === 0) return (im < 0 ? '−' : '') + ims;
    return fmt(re).replace('-', '−') + (im < 0 ? ' − ' : ' + ') + ims;
  }
  // 1, 2, 5 x 10^k at or above v
  function niceUp(v) {
    if (!(v > 0) || !Number.isFinite(v)) return 100;
    const e = Math.floor(Math.log10(v)), m = v / 10 ** e;
    return (m <= 1 ? 1 : m <= 2 ? 2 : m <= 5 ? 5 : 10) * 10 ** e;
  }
  // match the roots b to the previous roots a (greedy, nearest pairs first)
  function match(a, b) {
    const n = a.length, out = new Array(n), usedA = new Array(n).fill(false), usedB = new Array(n).fill(false), pairs = [];
    for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) pairs.push([Math.hypot(a[i][0] - b[j][0], a[i][1] - b[j][1]), i, j]);
    pairs.sort((p, q) => p[0] - q[0]);
    for (const [, i, j] of pairs) if (!usedA[i] && !usedB[j]) { out[i] = b[j]; usedA[i] = usedB[j] = true; }
    return out;
  }

  const L_DEFAULT = '1/((s-1)*(s+5)*(s+10))';   // same open loop as the old rlocus_animation.m

  function run(cfg) {
    const root = document.getElementById(cfg.mount || 'app');

    // ---- state ----
    let Lsys = null;           // {num, den, zeros, poles, Kmax, branches: [[{s, K}]], R}
    let K = 0, Kmax = 100, scale = 'log';
    let clPoles = [];
    let view = { cx: 0, cy: 0, half: 5 };
    let playing = false, hover = null, drag = null;
    const DEC = 4;             // log slider: Kmax*10^-DEC ... Kmax (position 0 is K = 0)
    const NPOS = 1000;

    // ---- DOM ----
    const cv = el('canvas', { class: 'np-plane np-s rl-plane', 'aria-label': 's-plane: root locus and closed-loop poles. Drag along the locus to set K.' });
    const lInput = el('input', { id: 'l-input', class: 'cs-input', type: 'text', spellcheck: 'false', autocomplete: 'off', 'aria-label': 'N(s)/D(s), the open loop without K' });
    const lErr = el('div', { class: 'cs-err', role: 'alert', hidden: '' });
    const lBox = el('div', { class: 'cs-tf' });
    const pzList = el('div', { class: 'cs-polelist' });
    const slK = el('input', { id: 'gain', class: 'cs-range', type: 'range', min: 0, max: NPOS, step: 1, value: 0, 'aria-label': 'Gain K' });
    slK.addEventListener('input', () => { stopPlay(); setK(posToK(+slK.value), true); });
    const kInput = el('input', { id: 'k-input', class: 'cs-input rl-num', type: 'number', min: 0, step: 'any', 'aria-label': 'Gain K' });
    kInput.addEventListener('change', () => { const v = parseFloat(kInput.value); if (v >= 0) { stopPlay(); if (v > Kmax) setKmax(niceUp(v)); setK(v); } });
    const kmaxInput = el('input', { id: 'kmax-input', class: 'cs-input rl-num', type: 'number', min: 0, step: 'any', 'aria-label': 'Largest K of the slider' });
    kmaxInput.addEventListener('change', () => { const v = parseFloat(kmaxInput.value); if (v > 0) { setKmax(v); setK(Math.min(K, v)); } else kmaxInput.value = fmt(Kmax); });
    const scaleSel = el('select', { class: 'cs-select', 'aria-label': 'Slider scale', onchange: e => { scale = e.target.value; setK(K); } },
      [el('option', { value: 'log', text: 'log slider' }), el('option', { value: 'linear', text: 'linear slider' })]);
    const btnPlay = el('button', { type: 'button', class: 'cs-btn', onclick: () => togglePlay() }, ['Play']);
    const badge = el('span', { class: 'cs-badge' });
    const clList = el('div', { class: 'cs-polelist' });
    const btn = (text, f) => el('button', { type: 'button', class: 'cs-btn', onclick: f }, [text]);

    const panel = el('aside', { class: 'cs-panel' }, [
      el('section', { class: 'cs-sec' }, [el('h2', { text: 'Open loop' }),
        el('form', { class: 'cs-cform', onsubmit: e => { e.preventDefault(); applyText(); } }, [
          el('label', { for: 'l-input', class: 'cs-lhs', text: 'L(s) = K ·' }), lInput, el('button', { type: 'submit', class: 'cs-btn cs-primary' }, ['Apply'])]),
        el('p', { class: 'cs-note', text: 'Type N(s)/D(s) only: K stays in front. Numbers, s, + − * / ^ and parentheses, e.g. (s+2)/(s*(s+1)*(s+5)).' }),
        lErr, lBox, pzList]),
      el('section', { class: 'cs-sec' }, [el('h2', { text: 'Gain K' }), slK,
        el('div', { class: 'rl-kform' }, [el('label', { for: 'k-input', class: 'cs-lhs', text: 'K =' }), kInput,
          el('label', { for: 'kmax-input', class: 'cs-note', text: 'max' }), kmaxInput]),
        el('div', { class: 'cs-row cs-mid' }, [btnPlay, scaleSel]),
        el('p', { class: 'cs-note', text: 'Play sweeps K from 0 to max. You can also drag a closed-loop pole (or any point) along the locus.' })]),
      el('section', { class: 'cs-sec' }, [el('h2', {}, ['Closed-loop poles ', badge]), clList]),
      el('section', { class: 'cs-sec' }, [el('h2', { text: 'View' }),
        el('div', { class: 'cs-row' }, [btn('Fit', () => fit())]),
        el('p', { class: 'cs-note', text: 'Drag the empty plane to pan, wheel to zoom. Keys: Space play, F fit.' })])
    ]);
    root.append(el('div', { class: 'fr-grid np-grid' }, [el('div', { class: 'np-main' }, [el('div', { class: 'fr-card' }, [cv])]), panel]));
    const ctx = CS.setupCanvas(cv);

    // ---- slider <-> K ----
    function posToK(p) {
      if (p <= 0) return 0;
      return scale === 'log' ? Kmax * 10 ** (-DEC * (1 - p / NPOS)) : Kmax * p / NPOS;
    }
    function kToPos(k) {
      if (k <= 0) return 0;
      if (scale === 'linear') return Math.round(NPOS * Math.min(k / Kmax, 1));
      return Math.max(1, Math.min(NPOS, Math.round(NPOS * (1 + Math.log10(k / Kmax) / DEC))));
    }

    // ---- L(s) ----
    function setL(num, den, text) {
      num = strip(num); den = strip(den);
      if (num.length === 1 && num[0] === 0) throw new Error('N(s) is zero: the open loop must not be zero.');
      if (den.length === 1 && den[0] === 0) throw new Error('The denominator of L(s) is zero.');
      if (num.length > den.length) throw new Error('L(s) has more zeros than poles (improper): the root locus needs deg N ≤ deg D.');
      if (den.length < 2) throw new Error('L(s) has no poles: type N(s)/D(s) with a D(s) of degree 1 or more.');
      const zeros = CS.roots(num), poles = CS.roots(den);
      Lsys = { num, den, zeros, poles };
      if (text !== undefined) lInput.value = text;
      const parts = CS.tfParts(num, den);
      lBox.replaceChildren(el('span', { class: 'cs-lhs', text: 'L(s) = K ·' }), parts.den
        ? el('span', { class: 'cs-frac' }, [el('span', { class: 'cs-num', text: parts.num }), el('span', { class: 'cs-den', text: parts.den })])
        : el('span', { class: 'cs-poly', text: parts.num }));
      const list = rs => rs.filter(r => r[1] >= 0).sort((a, b) => a[0] - b[0]).map(r => r[1] ? fmtC([r[0], Math.abs(r[1])]).replace(/ [+−] /, ' ± ') : fmtC(r)).join(',  ') || 'none';
      pzList.textContent = 'open-loop zeros (o): ' + list(zeros) + '\nopen-loop poles (×): ' + list(poles);
      // default slider range: |D/N| at a point on the scale of the poles and zeros
      const R = Math.max(1, ...poles.map(cabs), ...zeros.map(cabs));
      const s0 = [R * Math.cos(1.75), R * Math.sin(1.75)];
      const d0 = polyval(den, s0), n0 = polyval(num, s0);
      Lsys.R = R;
      setKmax(niceUp(cabs(d0) / Math.max(cabs(n0), 1e-12)), true);
      computeLocus();
      fit();
      setK(Kmax / 10 ** (DEC / 2));   // start in the middle of the log slider
    }
    function setKmax(v, quiet) {
      Kmax = v; kmaxInput.value = fmt(v);
      slK.value = kToPos(K);
      if (!quiet && Lsys) computeLocus();
    }
    function applyText() {
      try {
        const c = CS.parseC(lInput.value.replace(/L\(s\)\s*=?/g, '').replace(/^\s*K\s*\*?/, ''));
        setL(c.num, c.den);
        lErr.hidden = true;
      } catch (err) {
        lErr.textContent = err.message.replace(/C\(s\)/g, 'N(s)/D(s)') + ' The previous L(s) is still in use.';
        lErr.hidden = false;
      }
    }

    // ---- locus: roots of D + K N for K from 0 to well past Kmax ----
    function computeLocus() {
      const { num, den, poles } = Lsys;
      const n = den.length - 1;
      const step = Lsys.R * 0.01;
      const rootsAt = k => {
        const p = charPoly(den, num, k);
        if (Math.abs(p[0]) < 1e-12 * Math.max(...p.map(Math.abs))) return null;   // degree drops at this K
        const r = CS.roots(p);
        return r.length === n ? r : null;
      };
      let prev = poles.slice(), prevK = 0;
      const br = poles.map(p => [{ s: p, K: 0 }]);
      const add = (k, r) => { r.forEach((z, i) => br[i].push({ s: z, K: k })); prev = r; prevK = k; };
      const Ks = [];
      const k0 = Kmax * 1e-7, k1 = Kmax * 1e5, N = 700;
      for (let i = 0; i <= N; i++) Ks.push(k0 * (k1 / k0) ** (i / N));
      for (const k of Ks) {
        let r = rootsAt(k);
        if (!r) continue;
        r = match(prev, r);
        // refine where a root jumps (near break-away points)
        // (steps relative to the size of the root, so far-away asymptotic branches stay cheap)
        const jump = Math.max(...r.map((z, i) => Math.hypot(z[0] - prev[i][0], z[1] - prev[i][1]) / Math.max(1, cabs(z) / Lsys.R)));
        if (jump > step) {
          const m = Math.min(64, Math.ceil(jump / step));
          const ka = prevK || k0 / 10;
          for (let j = 1; j < m; j++) {
            const kk = ka * (k / ka) ** (j / m);
            const rr = rootsAt(kk);
            if (rr) add(kk, match(prev, rr));
          }
          r = match(prev, r);
        }
        add(k, r);
      }
      Lsys.branches = br;
    }

    function setK(k, fromSlider) {
      K = Math.max(0, k);
      if (!fromSlider) slK.value = kToPos(K);
      if (document.activeElement !== kInput) kInput.value = fmt(K);
      const p = charPoly(Lsys.den, Lsys.num, K);
      clPoles = Math.abs(p[0]) < 1e-12 * Math.max(...p.map(Math.abs)) ? CS.roots(p.slice(1)) : CS.roots(p);
      const unstable = clPoles.some(r => r[0] > 1e-9 * Math.max(1, cabs(r)));
      const marginal = !unstable && clPoles.some(r => Math.abs(r[0]) <= 1e-9 * Math.max(1, cabs(r)));
      badge.textContent = unstable ? 'unstable' : marginal ? 'marginal' : 'stable';
      badge.className = 'cs-badge ' + (unstable ? 'bad' : marginal ? 'warn' : 'ok');
      const rows = clPoles.filter(r => r[1] >= 0).sort((a, b) => b[0] - a[0]).map(r => {
        if (!r[1]) return fmtC(r);
        const wn = cabs(r), z = -r[0] / wn;
        return fmtC([r[0], r[1]]).replace(/ [+−] /, ' ± ') + '   (ζ = ' + fmt(+z.toFixed(3)) + ', ωn = ' + fmt(wn) + ')';
      });
      clList.textContent = 'K = ' + fmt(K) + '\n' + (rows.join('\n') || 'none');
    }

    // ---- view ----
    function xf() {
      const r = cv.getBoundingClientRect(), w = r.width, h = r.height, sc = Math.min(w, h) / (2 * view.half);
      return { w, h, sc, X: x => w / 2 + (x - view.cx) * sc, Y: y => h / 2 - (y - view.cy) * sc, inv: (px, py) => [view.cx + (px - w / 2) / sc, view.cy - (py - h / 2) / sc] };
    }
    function fit() {
      const pts = [[0, 0]].concat(Lsys.poles, Lsys.zeros);
      Lsys.branches.forEach(b => b.forEach(q => { if (q.K <= Kmax && cabs(q.s) < 50 * Lsys.R) pts.push(q.s); }));
      const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]);
      const x0 = Math.min(...xs), x1 = Math.max(...xs), y0 = Math.min(...ys), y1 = Math.max(...ys);
      const r = cv.getBoundingClientRect(), asp = r.height ? r.width / r.height : 1;
      const hx = (x1 - x0) / 2 / Math.max(asp, 1), hy = (y1 - y0) / 2 * Math.min(asp, 1);
      view = { cx: (x0 + x1) / 2, cy: 0, half: Math.max(1, 1.15 * Math.max(hx, hy, Math.max(Math.abs(y0), Math.abs(y1)) * Math.min(asp, 1)) + 0.3) };
    }
    function zoom(f, px, py) {
      const t = xf(), p = t.inv(px, py);
      view.half *= f; view.cx = p[0] + (view.cx - p[0]) * f; view.cy = p[1] + (view.cy - p[1]) * f;
    }
    // nearest locus point (in pixels) to the pointer
    function nearest(px, py) {
      const t = xf();
      let best = null, bd = Infinity;
      Lsys.branches.forEach(b => b.forEach(q => {
        const d = Math.hypot(t.X(q.s[0]) - px, t.Y(q.s[1]) - py);
        if (d < bd) { bd = d; best = q; }
      }));
      return best ? { q: best, d: bd } : null;
    }

    // ---- pointer ----
    const posOf = e => { const r = cv.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
    function pickK(px, py) {
      const nb = nearest(px, py);
      if (!nb) return;
      if (nb.q.K > Kmax) setKmax(niceUp(nb.q.K));
      setK(nb.q.K);
    }
    cv.addEventListener('pointerdown', e => {
      const [px, py] = posOf(e);
      cv.setPointerCapture(e.pointerId);
      const nb = nearest(px, py);
      if (nb && nb.d < 12) { stopPlay(); drag = { kind: 'k' }; pickK(px, py); }
      else drag = { kind: 'pan', last: [px, py] };
    });
    cv.addEventListener('pointermove', e => {
      const [px, py] = posOf(e);
      const nb = nearest(px, py);
      hover = nb && nb.d < 12 ? nb.q : null;
      if (!drag) return;
      if (drag.kind === 'k') pickK(px, py);
      else {
        const t = xf();
        view.cx -= (px - drag.last[0]) / t.sc; view.cy += (py - drag.last[1]) / t.sc; drag.last = [px, py];
      }
    });
    const endDrag = () => { drag = null; };
    cv.addEventListener('pointerup', endDrag);
    cv.addEventListener('pointercancel', endDrag);
    cv.addEventListener('pointerleave', () => { if (!drag) hover = null; });
    cv.addEventListener('wheel', e => { e.preventDefault(); const [px, py] = posOf(e); zoom(Math.exp(e.deltaY * 0.0015), px, py); }, { passive: false });

    function stopPlay() { playing = false; btnPlay.textContent = 'Play'; }
    function togglePlay() {
      playing = !playing; btnPlay.textContent = playing ? 'Pause' : 'Play';
      if (playing && +slK.value >= NPOS) { slK.value = 0; setK(0, true); }
    }
    document.addEventListener('keydown', e => {
      if (CS.isTyping(e)) return;
      const k = e.key.toLowerCase();
      if (e.key === ' ') togglePlay();
      else if (k === 'f') fit();
      else return;
      e.preventDefault();
    });

    // ---- drawing ----
    function grid(t, colors) {
      const [x0, y1] = t.inv(0, 0), [x1, y0] = t.inv(t.w, t.h);
      const n = Math.max(3, Math.round(Math.min(t.w, t.h) / 70));
      const st = CS.niceTicks(-view.half, view.half, n), d = st.length > 1 ? st[1] - st[0] : 1;
      ctx.lineWidth = 1; ctx.strokeStyle = colors.grid; ctx.beginPath();
      for (let x = Math.ceil(x0 / d) * d; x <= x1; x += d) { ctx.moveTo(t.X(x), 0); ctx.lineTo(t.X(x), t.h); }
      for (let y = Math.ceil(y0 / d) * d; y <= y1; y += d) { ctx.moveTo(0, t.Y(y)); ctx.lineTo(t.w, t.Y(y)); }
      ctx.stroke();
      ctx.font = '11px ' + colors.mono; ctx.fillStyle = colors.muted;
      const ax = Math.min(Math.max(t.Y(0), 8), t.h - 16), ay = Math.min(Math.max(t.X(0), 30), t.w - 8);
      ctx.textAlign = 'center'; ctx.textBaseline = 'top';
      for (let x = Math.ceil(x0 / d) * d; x <= x1; x += d) if (Math.abs(x) > d / 2) ctx.fillText(fmt(+x.toPrecision(6)), t.X(x), ax + 3);
      ctx.textAlign = 'right'; ctx.textBaseline = 'middle';
      for (let y = Math.ceil(y0 / d) * d; y <= y1; y += d) if (Math.abs(y) > d / 2) ctx.fillText(fmt(+y.toPrecision(6)), ay - 4, t.Y(y));
      ctx.strokeStyle = colors.muted; ctx.beginPath();
      ctx.moveTo(0, t.Y(0)); ctx.lineTo(t.w, t.Y(0)); ctx.moveTo(t.X(0), 0); ctx.lineTo(t.X(0), t.h); ctx.stroke();
      ctx.font = 'italic 14px ' + colors.body; ctx.fillStyle = colors.fg; ctx.textAlign = 'left'; ctx.textBaseline = 'alphabetic';
      ctx.fillText('σ', t.w - 16, Math.min(Math.max(t.Y(0), 20), t.h - 6) - 8);
      ctx.fillText('jω', Math.min(Math.max(t.X(0), 10), t.w - 30) + 6, 58);
    }
    const clampPx = v => Math.max(-1e5, Math.min(1e5, v));
    function draw() {
      const colors = CS.colorsNow();
      const r = CS.dpr();
      ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, cv.width, cv.height); ctx.scale(r, r);
      const t = xf();
      ctx.fillStyle = colors.unstableBg; ctx.fillRect(Math.max(0, t.X(0)), 0, t.w, t.h);
      grid(t, colors);
      if (!Lsys) return;
      // locus
      ctx.strokeStyle = colors.u; ctx.lineWidth = 2.2; ctx.lineJoin = 'round';
      Lsys.branches.forEach(b => {
        ctx.beginPath();
        b.forEach((q, i) => { const x = clampPx(t.X(q.s[0])), y = clampPx(t.Y(q.s[1])); i ? ctx.lineTo(x, y) : ctx.moveTo(x, y); });
        ctx.stroke();
      });
      // open-loop zeros and poles
      ctx.lineWidth = 2.2;
      Lsys.zeros.forEach(z => { ctx.strokeStyle = colors.out; ctx.fillStyle = colors.panel; ctx.beginPath(); ctx.arc(t.X(z[0]), t.Y(z[1]), 6, 0, TAU); ctx.fill(); ctx.stroke(); });
      Lsys.poles.forEach(p => {
        const x = t.X(p[0]), y = t.Y(p[1]), s = 6;
        ctx.strokeStyle = colors.part; ctx.beginPath(); ctx.moveTo(x - s, y - s); ctx.lineTo(x + s, y + s); ctx.moveTo(x + s, y - s); ctx.lineTo(x - s, y + s); ctx.stroke();
      });
      // closed-loop poles at the current K
      clPoles.forEach(p => {
        ctx.beginPath(); ctx.arc(t.X(p[0]), t.Y(p[1]), 7, 0, TAU);
        ctx.fillStyle = colors.pole; ctx.fill(); ctx.strokeStyle = colors.panel; ctx.lineWidth = 2; ctx.stroke();
      });
      if (hover && !drag) {
        ctx.beginPath(); ctx.arc(t.X(hover.s[0]), t.Y(hover.s[1]), 5, 0, TAU); ctx.strokeStyle = colors.fg; ctx.lineWidth = 1.5; ctx.stroke();
      }
      // title
      const text = 'Root locus: roots of D(s) + K N(s) = 0, K ≥ 0';
      const note = hover && !drag ? 'here: K = ' + fmt(hover.K) + ',  s = ' + fmtC(hover.s) : 'K = ' + fmt(K) + ':  ● closed-loop poles,  × open-loop poles,  o zeros';
      ctx.textAlign = 'left'; ctx.textBaseline = 'top';
      ctx.font = '12px ' + colors.body; const wn = ctx.measureText(note).width;
      ctx.font = '700 13px ' + colors.body;
      ctx.globalAlpha = 0.85; ctx.fillStyle = colors.panel; ctx.fillRect(4, 4, Math.max(ctx.measureText(text).width, wn) + 12, 38); ctx.globalAlpha = 1;
      ctx.fillStyle = colors.fg; ctx.fillText(text, 10, 8);
      ctx.font = '12px ' + colors.body; ctx.fillStyle = colors.muted; ctx.fillText(note, 10, 26);
    }

    // ---- loop ----
    let last = performance.now();
    function frame(now) {
      const dt = Math.min((now - last) / 1000, 0.05); last = now;
      if (playing) {
        let p = +slK.value + dt * NPOS / 8;   // 8 s from K = 0 to Kmax
        if (p >= NPOS) { p = NPOS; stopPlay(); }
        slK.value = p; setK(posToK(p), true);
      }
      draw();
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(() => {
      lInput.value = cfg.L || L_DEFAULT;
      applyText();
      requestAnimationFrame(frame);
    });

    // for tests
    window.RootLocusDemo = { state: () => ({ Lsys, K, Kmax, clPoles, view }), setL: str => { lInput.value = str; applyText(); }, setK, setKmax };
  }

  window.RootLocusSim = { run };
})();
