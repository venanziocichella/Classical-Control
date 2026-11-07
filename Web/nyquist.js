/* nyquist.js - contour mapping demo of Chapter 9 (port of NYQ_Mapping_Demo.m).
 * Needs engine.js (ControlSim: parser, roots, page helpers).
 *
 * Left: the s-plane, with the poles (x) and zeros (o) of L(s). Draw a curve or
 * a closed contour on it. Right: the L-plane, with the image L(s) of the
 * contour, updated while you draw. For a closed contour (the Nyquist contour,
 * or a curve that ends where it started) the demo counts the encirclements of
 * -1 and the poles inside (Z = N + P), and a point moving along the contour
 * shows the phasors.
 */
(function () {
  'use strict';
  const CS = window.ControlSim, el = CS.el, fmt = CS.fmt;
  const TAU = 2 * Math.PI;

  // ---- complex numbers as [re, im] ----
  const csub = (a, b) => [a[0] - b[0], a[1] - b[1]];
  const cabs = a => Math.hypot(a[0], a[1]);
  const carg = a => Math.atan2(a[1], a[0]);
  function cdiv(a, b) {
    const m = b[0] * b[0] + b[1] * b[1];
    if (m === 0) return [Infinity, Infinity];
    return [(a[0] * b[0] + a[1] * b[1]) / m, (a[1] * b[0] - a[0] * b[1]) / m];
  }
  function polyval(p, s) {   // descending real coefficients at complex s (Horner)
    let re = 0, im = 0;
    for (const a of p) { const t = re * s[0] - im * s[1] + a; im = re * s[1] + im * s[0]; re = t; }
    return [re, im];
  }
  const wrapPi = a => a - TAU * Math.round(a / TAU);
  const fin = a => a && Number.isFinite(a[0]) && Number.isFinite(a[1]);
  function fmtC(z) {
    const tol = 1e-9 * Math.max(1, cabs(z));
    const re = Math.abs(z[0]) < tol ? 0 : z[0], im = Math.abs(z[1]) < tol ? 0 : z[1];
    if (im === 0) return fmt(re).replace('-', '−');
    const ims = fmt(Math.abs(im)) + 'j';
    if (re === 0) return (im < 0 ? '−' : '') + ims;
    return fmt(re).replace('-', '−') + (im < 0 ? ' − ' : ' + ') + ims;
  }
  const strip = p => { const k = p.findIndex(v => v !== 0); return k < 0 ? [0] : p.slice(k); };
  function padAdd(a, b, kb) {   // a + kb*b, descending
    const n = Math.max(a.length, b.length), r = [];
    for (let i = 0; i < n; i++) r.push((a[i - n + a.length] || 0) + kb * (b[i - n + b.length] || 0));
    return strip(r);
  }
  function polyFromRoots(rs) {   // real polynomial from roots (pairs already conjugate)
    let p = [[1, 0]];
    for (const r of rs) {
      const q = p.map(c => c.slice()).concat([[0, 0]]);
      for (let i = 1; i < q.length; i++) {   // q = p*(s - r)
        q[i][0] -= p[i - 1][0] * r[0] - p[i - 1][1] * r[1];
        q[i][1] -= p[i - 1][0] * r[1] + p[i - 1][1] * r[0];
      }
      p = q;
    }
    return p.map(c => c[0]);
  }
  // L(s) as text from gain, zeros and poles, e.g. 2*(s-2)*((s-2)^2+4)/((s+4)*(s+1)*(s-3))
  function factorText(K, zs, ps) {
    const fac = rs => {
      const out = [], used = new Array(rs.length).fill(false);
      const num = (v, plus) => (v < 0 ? '-' : plus ? '+' : '') + fmt(Math.abs(v));
      rs.forEach((r, i) => {
        if (used[i]) return;
        used[i] = true;
        if (r[1] === 0) { out.push(r[0] === 0 ? 's' : '(s' + num(-r[0], true) + ')'); return; }
        const j = rs.findIndex((q, k) => !used[k] && Math.abs(q[0] - r[0]) < 1e-9 && Math.abs(q[1] + r[1]) < 1e-9);
        if (j >= 0) used[j] = true;
        const b2 = r[1] * r[1];
        out.push(r[0] === 0 ? '(s^2+' + fmt(b2) + ')' : '((s' + num(-r[0], true) + ')^2+' + fmt(b2) + ')');
      });
      return out;
    };
    const n = fac(zs), d = fac(ps);
    let str = n.join('*');
    if (K !== 1 || !str) str = fmt(K) + (str ? '*' + str : '');
    if (d.length) str += '/' + (d.length > 1 ? '(' + d.join('*') + ')' : d[0]);
    return str;
  }

  // Default open loop shown at start (cfg.L overrides it), with the Nyquist contour.
  const L_DEFAULT = '50/((s+1)*(s+2)*(s+3))';

  function run(cfg) {
    const root = document.getElementById(cfg.mount || 'app');

    // ---- state ----
    let Lsys = null;                 // {num, den, zeros, poles, K}
    let kGain = 1, clRoots = [];     // zeros of 1 + k L
    let contour = null;              // {pts, closed, kind}
    let tool = 'draw', scale = cfg.scale || 'linear';
    const center = -1;               // encirclements are always counted around -1
    let sView = { cx: 0, cy: 0, half: 5 }, lView = { cx: 0, cy: 0, half: 2 }, lTarget = null, lAuto = true;
    let img = null, dirty = true;
    let tr = 0, playing = false, hoverS = null;
    let drag = null;                 // current pointer action

    // ---- DOM ----
    const sCv = el('canvas', { class: 'np-plane np-s', 'aria-label': 's-plane: draw a contour here' });
    const lCv = el('canvas', { class: 'np-plane', 'aria-label': 'L-plane: image of the contour' });
    const phCv = el('canvas', { class: 'np-phase', 'aria-label': 'phase of L along the contour' });
    const lInput = el('input', { id: 'l-input', class: 'cs-input', type: 'text', spellcheck: 'false', autocomplete: 'off', 'aria-label': 'Open loop L(s)' });
    const lErr = el('div', { class: 'cs-err', role: 'alert', hidden: '' });
    const lBox = el('div', { class: 'cs-tf' });
    const pzList = el('div', { class: 'cs-polelist' });
    const slK = el('input', { id: 'gain', class: 'cs-range', type: 'range', min: -2, max: 2, step: 0.001, value: 0, 'aria-label': 'Gain k' });
    const lblK = el('div', { class: 'fr-val' });
    slK.addEventListener('input', () => setK(10 ** +slK.value));
    const toolBtns = {};
    const toolRow = el('div', { class: 'cs-row np-tools' }, [['draw', 'Draw'], ['move', 'Move']].map(([k, t]) => {
      toolBtns[k] = el('button', { type: 'button', class: 'cs-btn cs-toggle', 'aria-pressed': 'false', onclick: () => setTool(k) }, [t]);
      return toolBtns[k];
    }));
    const badge = el('span', { class: 'cs-badge' });
    const countBox = el('div', { class: 'np-count' });
    const verdict = el('div', { class: 'np-verdict' });
    const btnPlay = el('button', { type: 'button', class: 'cs-btn', onclick: () => togglePlay() }, ['Play']);
    const slT = el('input', { id: 'tracer', class: 'cs-range', type: 'range', min: 0, max: 1, step: 0.0005, value: 0, 'aria-label': 'Position along the contour' });
    slT.addEventListener('input', () => { tr = +slT.value; playing = false; btnPlay.textContent = 'Play'; });
    const trBox = el('div', { class: 'fr-val np-tracer' });
    const scaleSel = el('select', { class: 'cs-select', 'aria-label': 'L-plane scale', onchange: e => { scale = e.target.value; lAuto = true; chkAuto.checked = true; dirty = true; } },
      [el('option', { value: 'linear', text: 'linear |L|' }), el('option', { value: 'log', text: 'compressed |L| (log)' })]);
    const chkAuto = el('input', { type: 'checkbox', id: 'lauto', checked: '' });
    chkAuto.addEventListener('change', () => { lAuto = chkAuto.checked; dirty = true; });
    const chkUnit = el('input', { type: 'checkbox', id: 'unit' });
    const btn = (text, f) => el('button', { type: 'button', class: 'cs-btn', onclick: f }, [text]);
    const check = (box, text) => el('label', { class: 'np-check' }, [box, ' ' + text]);

    const panel = el('aside', { class: 'cs-panel' }, [
      el('section', { class: 'cs-sec' }, [el('h2', { text: 'Mapping function L(s)' }),
        el('form', { class: 'cs-cform', onsubmit: e => { e.preventDefault(); applyText(); } }, [
          el('label', { for: 'l-input', class: 'cs-lhs', text: 'L(s) =' }), lInput, el('button', { type: 'submit', class: 'cs-btn cs-primary' }, ['Apply'])]),
        lErr, lBox, pzList,
        el('label', { for: 'gain', class: 'cs-note', text: 'Gain k: the right plot shows k·L(s)' }), slK, lblK]),
      el('section', { class: 'cs-sec' }, [el('h2', { text: 'Contour' }), toolRow,
        el('div', { class: 'cs-row' }, [btn('Nyquist contour', () => setNyquist()), btn('Clear', () => clear())]),
        el('p', { class: 'cs-note', text: 'Draw: freehand; end where you started to close the curve. Move: drag the contour, a pole or a zero (L(s) follows), or the empty plane to pan. Wheel: zoom.' })]),
      el('section', { class: 'cs-sec' }, [el('h2', {}, ['Encirclements of −1 ', badge]), countBox, verdict]),
      el('section', { class: 'cs-sec' }, [el('h2', { text: 'Moving point' }),
        el('div', { class: 'cs-row' }, [btnPlay]), slT, trBox]),
      el('section', { class: 'cs-sec' }, [el('h2', { text: 'View' }),
        el('div', { class: 'cs-row' }, [scaleSel, btn('Fit s-plane', () => fitS()), btn('Fit L-plane', () => { lAuto = true; chkAuto.checked = true; dirty = true; })]),
        check(chkAuto, 'auto-fit the L-plane'), check(chkUnit, 'unit circle |L| = 1'),
        el('p', { class: 'cs-note', text: 'Keys: Space play, N Nyquist contour, C clear, F fit. Compressed scale: |L| > 1 is drawn at radius 1 + ln|L|, so points near a pole stay on the screen.' })])
    ]);
    const card = (cv, extra) => el('div', { class: 'fr-card' + (extra || '') }, [cv]);
    root.append(el('div', { class: 'fr-grid np-grid' }, [
      el('div', { class: 'np-main' }, [el('div', { class: 'np-planes' }, [card(sCv), card(lCv)]), card(phCv)]), panel]));
    const sCtx = CS.setupCanvas(sCv), lCtx = CS.setupCanvas(lCv), phCtx = CS.setupCanvas(phCv);
    new ResizeObserver(() => { dirty = true; }).observe(lCv);

    // ---- L(s) ----
    function setL(num, den, text) {
      num = strip(num); den = strip(den);
      if (den.length === 1 && den[0] === 0) throw new Error('The denominator of L(s) is zero.');
      const zeros = CS.roots(num), poles = CS.roots(den);
      Lsys = { num, den, zeros, poles, K: num[0] / den[0] };
      if (text !== undefined) lInput.value = text;
      const parts = CS.tfParts(num, den);
      lBox.replaceChildren(el('span', { class: 'cs-lhs', text: 'L(s) =' }), parts.den
        ? el('span', { class: 'cs-frac' }, [el('span', { class: 'cs-num', text: parts.num }), el('span', { class: 'cs-den', text: parts.den })])
        : el('span', { class: 'cs-poly', text: parts.num }));
      const list = rs => rs.filter(r => r[1] >= 0).sort((a, b) => a[0] - b[0]).map(r => r[1] ? fmtC([r[0], Math.abs(r[1])]).replace(/ [+−] /, ' ± ') : fmtC(r)).join(',  ') || 'none';
      pzList.textContent = 'zeros (o): ' + list(zeros) + '\npoles (×): ' + list(poles);
      updateCl();
    }
    function updateCl() {
      clRoots = CS.roots(padAdd(Lsys.den, Lsys.num, kGain));
      dirty = true;
    }
    function setK(k) {
      kGain = k; slK.value = Math.log10(k);
      lblK.textContent = 'k = ' + fmt(k) + (k === 1 ? '' : '   (plotted: ' + fmt(k) + '·L(s))');
      updateCl();
    }
    function applyText() {
      try {
        const c = CS.parseC(lInput.value.replace(/L\(s\)/g, ''));
        setL(c.num, c.den);
        lErr.hidden = true;
      } catch (err) {
        lErr.textContent = err.message.replace(/C\(s\)/g, 'L(s)') + ' The previous L(s) is still in use.';
        lErr.hidden = false;
      }
    }
    function rebuildFromRoots() {
      const { K, zeros, poles } = Lsys;
      setL(polyFromRoots(zeros).map(v => K * v), polyFromRoots(poles), factorText(K, zeros, poles));
      Lsys.zeros = zeros; Lsys.poles = poles;   // keep the dragged values exactly
    }
    const Lof = s => { const v = cdiv(polyval(Lsys.num, s), polyval(Lsys.den, s)); return [kGain * v[0], kGain * v[1]]; };
    // plotted point: linear, or compressed magnitude 1 + ln|L| above 1 (smooth at |L| = 1)
    function plotPt(L) {
      if (!fin(L)) return null;
      if (scale === 'linear') return L;
      const r = cabs(L);
      if (r <= 1) return L;
      const rc = 1 + Math.log(r);
      return [L[0] * rc / r, L[1] * rc / r];
    }

    // ---- contours ----
    function nyquistPts() {
      // Up the imaginary axis (indenting to the right of poles on it), then the
      // clockwise semicircle of radius R; starts at s = 0+.
      const mags = Lsys.poles.concat(Lsys.zeros).map(cabs);
      const big = Math.max(1, ...mags), R = 200 * big;
      const axisP = Lsys.poles.filter(p => Math.abs(p[0]) < 1e-9 * big).map(p => p[1]).sort((a, b) => a - b);
      let eps = 0.04 * sView.half;
      for (let i = 1; i < axisP.length; i++) if (axisP[i] - axisP[i - 1] > 1e-12) eps = Math.min(eps, 0.3 * (axisP[i] - axisP[i - 1]));
      const wl = Math.max(2 * sView.half, 2 * big), wp = [];
      for (let k = 0; k <= 300; k++) wp.push(wl * k / 300);
      for (let k = 1; k <= 150; k++) wp.push(wl * (R / wl) ** (k / 150));
      const ws = wp.slice(1).reverse().map(v => -v).concat(wp);
      const axis = [];
      let ip = 0;
      for (const w of ws) {
        while (ip < axisP.length && axisP[ip] + eps < w) {   // indentation around j*axisP[ip]
          const wp0 = axisP[ip];
          for (let k = 0; k <= 30; k++) { const a = -Math.PI / 2 + Math.PI * k / 30; axis.push([eps * Math.cos(a), wp0 + eps * Math.sin(a)]); }
          ip++;
          while (ip < axisP.length && Math.abs(axisP[ip] - wp0) < 1e-12) ip++;   // repeated poles
        }
        if (axisP.some(p => Math.abs(w - p) <= eps)) continue;
        axis.push([0, w]);
      }
      const arc = [];
      for (let k = 1; k < 120; k++) { const a = Math.PI / 2 - Math.PI * k / 120; arc.push([R * Math.cos(a), R * Math.sin(a)]); }
      const all = axis.concat(arc);
      const i0 = axis.findIndex(p => p[1] > 0 || (p[1] === 0 && p[0] >= 0));
      return all.slice(i0).concat(all.slice(0, i0));
    }
    function setContour(pts, closed, kind) { contour = pts && pts.length > 1 ? { pts, closed, kind: kind || 'free' } : null; tr = 0; slT.value = 0; dirty = true; }
    function setNyquist() { setContour(nyquistPts(), true, 'nyquist'); }
    function clear() { setContour(null); playing = false; btnPlay.textContent = 'Play'; }
    function init() {
      lInput.value = cfg.L || L_DEFAULT; applyText(); setK(1);
      scaleSel.value = scale;
      fitS();
      setNyquist();
    }

    // ---- geometry ----
    function windingAround(pts, q) {   // signed number of turns of the closed polyline around q (ccw > 0)
      let sum = 0;
      for (let i = 0; i < pts.length; i++) {
        const a = pts[i], b = pts[(i + 1) % pts.length];
        sum += wrapPi(Math.atan2(b[1] - q[1], b[0] - q[0]) - Math.atan2(a[1] - q[1], a[0] - q[0]));
      }
      return Math.round(sum / TAU);
    }
    function distToPolyline(pts, closed, q) {
      let d = Infinity;
      const n = closed ? pts.length : pts.length - 1;
      for (let i = 0; i < n; i++) {
        const a = pts[i], b = pts[(i + 1) % pts.length], ab = [b[0] - a[0], b[1] - a[1]];
        const L2 = ab[0] * ab[0] + ab[1] * ab[1];
        const t = L2 ? Math.min(1, Math.max(0, ((q[0] - a[0]) * ab[0] + (q[1] - a[1]) * ab[1]) / L2)) : 0;
        d = Math.min(d, Math.hypot(a[0] + t * ab[0] - q[0], a[1] + t * ab[1] - q[1]));
      }
      return d;
    }
    const signedArea = pts => pts.reduce((s, a, i) => { const b = pts[(i + 1) % pts.length]; return s + a[0] * b[1] - b[0] * a[1]; }, 0) / 2;

    // ---- the image: sample the contour, refine where the image moves fast ----
    function compute() {
      dirty = false;
      if (!contour || !Lsys) { img = null; return; }
      const verts = contour.closed ? contour.pts.concat([contour.pts[0]]) : contour.pts;
      const step = sView.half / 120, cap = sView.half / 40;
      const S = [], T = [];
      let wsum = 0;
      for (let i = 0; i + 1 < verts.length; i++) {
        const a = verts[i], b = verts[i + 1], len = Math.hypot(b[0] - a[0], b[1] - a[1]);
        const n = contour.kind === 'nyquist' ? 1 : Math.min(60, Math.max(1, Math.ceil(len / step)));
        for (let j = 0; j < n; j++) { S.push([a[0] + (b[0] - a[0]) * j / n, a[1] + (b[1] - a[1]) * j / n]); T.push(wsum); wsum += Math.min(len, cap) / n; }
      }
      S.push(verts[verts.length - 1]); T.push(wsum);
      const Lb = S.map(Lof), Pb = Lb.map(plotPt);
      if (lAuto) lTarget = robustView(Pb);
      const half = lAuto ? lTarget.half : lView.half;
      const tolD = 0.012 * half, jump = 0.25 * half;
      const farR = 20 * half + (lAuto ? Math.hypot(lTarget.cx, lTarget.cy) : Math.hypot(lView.cx, lView.cy));
      const oS = [S[0]], oL = [Lb[0]], oP = [Pb[0]], oT = [T[0]], brk = [false];
      let budget = 60000;
      const angBad = (La, Lc) => Math.abs(wrapPi(carg(csub(Lc, [center, 0])) - carg(csub(La, [center, 0])))) > 0.3;
      function rec(sa, La, Pa, ta, sb, Lb2, Pb2, tb, depth) {
        // far outside the view only the direction matters (the curve there is not drawn)
        const far = Pa && Pb2 && cabs(Pa) > farR && cabs(Pb2) > farR;
        const bad = !Pa || !Pb2 || (!far && Math.hypot(Pa[0] - Pb2[0], Pa[1] - Pb2[1]) > tolD) || angBad(La, Lb2);
        if (!bad) return false;
        if (depth >= 14 || budget <= 0) return !Pa || !Pb2 || Math.hypot(Pa[0] - Pb2[0], Pa[1] - Pb2[1]) > jump;
        const sm = [(sa[0] + sb[0]) / 2, (sa[1] + sb[1]) / 2], Lm = Lof(sm), Pm = plotPt(Lm), tm = (ta + tb) / 2;
        budget--;
        const b1 = rec(sa, La, Pa, ta, sm, Lm, Pm, tm, depth + 1);
        oS.push(sm); oL.push(Lm); oP.push(Pm); oT.push(tm); brk.push(b1);
        return rec(sm, Lm, Pm, tm, sb, Lb2, Pb2, tb, depth + 1);
      }
      for (let i = 1; i < S.length; i++) {
        const b = rec(S[i - 1], Lb[i - 1], Pb[i - 1], T[i - 1], S[i], Lb[i], Pb[i], T[i], 0);
        oS.push(S[i]); oL.push(Lb[i]); oP.push(Pb[i]); oT.push(T[i]); brk.push(b);
      }
      const Ttot = wsum || 1;
      for (let i = 0; i < oT.length; i++) oT[i] /= Ttot;

      // poles / zeros on the contour: the image goes through infinity (or 0) there
      const near = 0.006 * sView.half;
      const onC = [];
      Lsys.poles.forEach(p => { if (distToPolyline(contour.pts, contour.closed, p) < near) onC.push('pole ' + fmtC(p)); });
      clRoots.forEach(z => { if (distToPolyline(contour.pts, contour.closed, z) < near) onC.push('zero of 1 + kL at ' + fmtC(z)); });

      // unwrapped phase of L - c along the contour, and its net change
      const c = [center, 0], phase = new Array(oL.length).fill(NaN);
      let acc = 0, ok = true, prev = null;
      for (let i = 0; i < oL.length; i++) {
        if (!fin(oL[i]) || cabs(csub(oL[i], c)) === 0) { ok = false; prev = null; continue; }
        const a = carg(csub(oL[i], c));
        if (prev === null) { if (i > 0) ok = false; acc = i === 0 ? a : acc; }
        else { if (brk[i]) ok = false; acc += wrapPi(a - prev); }
        phase[i] = acc * 180 / Math.PI; prev = a;
      }
      const turns = (phase[phase.length - 1] - phase[0]) / 360;
      // phasor angles of each root, unwrapped along the contour (for the table)
      const rootsAll = Lsys.zeros.map(z => ({ z, zero: true })).concat(Lsys.poles.map(z => ({ z, zero: false })));
      rootsAll.forEach(r => {
        const arr = new Float64Array(oS.length);
        let pa = carg(csub(oS[0], r.z)), ac = pa;
        arr[0] = ac;
        for (let i = 1; i < oS.length; i++) { const a = carg(csub(oS[i], r.z)); ac += wrapPi(a - pa); pa = a; arr[i] = ac; }
        r.ang = arr;
      });
      img = { S: oS, L: oL, P: oP, T: oT, brk, phase, onC, rootsAll, closed: contour.closed,
              wind: contour.closed && ok && !onC.length && Math.abs(turns - Math.round(turns)) < 0.05 ? Math.round(turns) : null };
      updateCount();
    }
    function robustView(P) {
      const pts = P.filter(Boolean);
      const keep = [[0, 0], [center, 0]];
      if (pts.length) {
        const mags = pts.map(cabs).sort((a, b) => a - b), q = mags[Math.floor(0.9 * (mags.length - 1))];
        pts.forEach(p => { if (cabs(p) <= 2.5 * q + 1e-12) keep.push(p); });
      }
      const xs = keep.map(p => p[0]), ys = keep.map(p => p[1]);
      const [x0, x1, y0, y1] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)];
      const r = lCv.getBoundingClientRect(), asp = r.height ? r.width / r.height : 1;
      const half = Math.max(0.5, 1.15 * Math.max((y1 - y0) / 2 * (asp < 1 ? asp : 1), (x1 - x0) / 2 / (asp > 1 ? asp : 1)));
      return { cx: (x0 + x1) / 2, cy: (y0 + y1) / 2, half };
    }

    // ---- counting ----
    function updateCount() {
      const rows = [];
      let v = '', cls = '';
      if (!img || !contour) {
        badge.textContent = ''; badge.className = 'cs-badge';
        countBox.textContent = 'Draw a closed contour on the s-plane.';
        verdict.textContent = ''; return;
      }
      if (!img.closed) {
        badge.textContent = 'open curve'; badge.className = 'cs-badge warn';
        countBox.textContent = 'An open curve maps to an open curve. End the curve where you started (or use the Nyquist contour) to count encirclements.';
        verdict.textContent = ''; return;
      }
      const cw = signedArea(contour.pts) < 0, dirW = cw ? 'clockwise' : 'counterclockwise', sg = cw ? -1 : 1;
      const Nsym = cw ? 'N_cw' : 'N_ccw';
      const inside = rs => rs.reduce((s, r) => s + sg * windingAround(contour.pts, r), 0);
      const P = inside(Lsys.poles), Zcl = inside(clRoots);
      rows.push('Contour: closed, traced ' + dirW + (contour.kind === 'nyquist' ? ' (Nyquist contour)' : '') + '.');
      if (img.onC.length) {
        badge.textContent = 'undefined'; badge.className = 'cs-badge bad';
        rows.push('The contour passes through the ' + img.onC.join(', ') + '. There L(s) is ' + (img.onC[0].startsWith('pole') ? 'infinite' : '−1') +
          ' and the argument principle does not apply. Move the contour a little.');
        countBox.textContent = rows.join('\n'); verdict.textContent = ''; return;
      }
      const N = img.wind === null ? null : sg * img.wind;   // turns in the direction of the contour
      const enc = n => n === 0 ? 'does not encircle' : 'encircles ' + Math.abs(n) + '× ' + (n > 0 ? 'counterclockwise' : 'clockwise') + ' around';
        rows.push('Poles of L(s) inside: P = ' + P + '.');
        rows.push(N === null ? 'Image: could not count (refine the view).' : 'Image ' + enc(img.wind) + ' −1: ' + Nsym + ' = ' + N + '.');
        if (N !== null) {
          rows.push('Zeros of 1 + kL(s) inside: Z = ' + Nsym + ' + P = ' + (N + P) + (N + P === Zcl ? ' (check: roots of 1 + kL give ' + Zcl + ')' : ' (roots of 1 + kL give ' + Zcl + ')'));
          if (contour.kind === 'nyquist' && cw) {
            v = N + P === 0 ? 'Closed loop stable: Z = 0' : 'Closed loop unstable: Z = ' + (N + P) + ' pole' + (N + P === 1 ? '' : 's') + ' in the RHP';
            cls = N + P === 0 ? 'ok' : 'bad';
          } else { v = 'Z = ' + Nsym + ' + P = ' + (N + P); cls = N + P === Zcl ? 'ok' : 'bad'; }
        }
        const shown = clRoots.filter(r => r[1] >= -1e-12).sort((a, b) => b[0] - a[0]);
        rows.push('Roots of 1 + kL(s): ' + (shown.map(r => r[1] > 0 ? fmtC([r[0], r[1]]).replace(/ [+−] /, ' ± ') : fmtC(r)).join(',  ') || 'none'));
        badge.textContent = ''; badge.className = 'cs-badge';
      countBox.textContent = rows.join('\n');
      verdict.textContent = v; verdict.className = 'np-verdict ' + cls;
    }

    // ---- views ----
    function fitS() {
      const pts = Lsys ? Lsys.poles.concat(Lsys.zeros, clRoots.length < 12 ? [] : []) : [];
      if (contour && contour.kind !== 'nyquist') contour.pts.forEach(p => pts.push(p));
      pts.push([0, 0]);
      const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]);
      const [x0, x1, y0, y1] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)];
      const r = sCv.getBoundingClientRect(), asp = r.height ? r.width / r.height : 1;
      const half = Math.max(1.5, 1.3 * Math.max((y1 - y0) / 2 * (asp < 1 ? asp : 1), (x1 - x0) / 2 / (asp > 1 ? asp : 1)) + 0.5);
      sView = { cx: (x0 + x1) / 2, cy: (y0 + y1) / 2, half };
      dirty = true;
    }
    function xf(cv, v) {   // world <-> CSS pixels for a view
      const r = cv.getBoundingClientRect(), w = r.width, h = r.height, sc = Math.min(w, h) / (2 * v.half);
      return {
        w, h, sc,
        X: x => w / 2 + (x - v.cx) * sc, Y: y => h / 2 - (y - v.cy) * sc,
        inv: (px, py) => [v.cx + (px - w / 2) / sc, v.cy - (py - h / 2) / sc]
      };
    }
    function zoom(v, cv, f, px, py) {
      const t = xf(cv, v), p = t.inv(px, py);
      v.half *= f; v.cx = p[0] + (v.cx - p[0]) * f; v.cy = p[1] + (v.cy - p[1]) * f;
    }

    // ---- pointer on the s-plane ----
    const posOf = (cv, e) => { const r = cv.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
    function setTool(k) { tool = k; for (const b in toolBtns) toolBtns[b].setAttribute('aria-pressed', String(b === k)); }
    sCv.addEventListener('pointerdown', e => {
      const [px, py] = posOf(sCv, e), t = xf(sCv, sView), s = t.inv(px, py);
      sCv.setPointerCapture(e.pointerId);
      if (tool === 'draw') { drag = { kind: 'draw', pts: [s] }; setContour([s, s], false); }
      else {
        // nearest pole/zero within 12 px
        let best = null, bd = 12;
        const consider = (arr, zero) => arr.forEach((r, i) => { const d = Math.hypot(t.X(r[0]) - px, t.Y(r[1]) - py); if (d < bd) { bd = d; best = { arr, i, zero }; } });
        if (Lsys) { consider(Lsys.zeros, true); consider(Lsys.poles, false); }
        if (best) {
          const r = best.arr[best.i];
          const mate = r[1] === 0 ? -1 : best.arr.findIndex((q, k) => k !== best.i && Math.abs(q[0] - r[0]) < 1e-6 * (1 + cabs(r)) && Math.abs(q[1] + r[1]) < 1e-6 * (1 + cabs(r)));
          drag = { kind: 'root', arr: best.arr, i: best.i, mate, real: r[1] === 0 };
        } else if (contour && (distToPolyline(contour.pts, contour.closed, s) * t.sc < 10 || (contour.closed && windingAround(contour.pts, s) !== 0))) {
          drag = { kind: 'move', last: s };
        } else drag = { kind: 'pan', last: [px, py] };
      }
    });
    sCv.addEventListener('pointermove', e => {
      const [px, py] = posOf(sCv, e), t = xf(sCv, sView), s = t.inv(px, py);
      hoverS = s;
      if (!drag) return;
      if (drag.kind === 'draw') {
        const l = drag.pts[drag.pts.length - 1];
        if (Math.hypot(t.X(l[0]) - px, t.Y(l[1]) - py) >= 3) { drag.pts.push(s); contour = { pts: drag.pts.slice(), closed: false, kind: 'free' }; dirty = true; }
      } else if (drag.kind === 'move') {
        const dx = s[0] - drag.last[0], dy = s[1] - drag.last[1];
        contour.pts = contour.pts.map(p => [p[0] + dx, p[1] + dy]); contour.kind = contour.kind === 'nyquist' ? 'free' : contour.kind;
        drag.last = s; dirty = true;
      } else if (drag.kind === 'pan') {
        sView.cx -= (px - drag.last[0]) / t.sc; sView.cy += (py - drag.last[1]) / t.sc; drag.last = [px, py]; dirty = true;
      } else if (drag.kind === 'root') {
        const snap = 6 / t.sc;
        let v = [s[0], s[1]];
        if (drag.real || Math.abs(v[1]) < snap) v[1] = 0;
        if (Math.abs(v[0]) < snap) v[0] = 0;
        if (drag.real) drag.arr[drag.i] = v;
        else if (v[1] === 0) { drag.arr[drag.i] = [v[0], 0.5 * snap]; if (drag.mate >= 0) drag.arr[drag.mate] = [v[0], -0.5 * snap]; }
        else { drag.arr[drag.i] = v; if (drag.mate >= 0) drag.arr[drag.mate] = [v[0], -v[1]]; }
        rebuildFromRoots();
      }
    });
    const endDrag = () => {
      if (drag && drag.kind === 'draw') {
        if (drag.pts.length < 3) setContour(null);
        else {   // closed only if it ends where it started (within 12 px)
          const t = xf(sCv, sView), a = drag.pts[0], b = drag.pts[drag.pts.length - 1];
          const closed = Math.hypot(a[0] - b[0], a[1] - b[1]) * t.sc < 12 && drag.pts.length > 8;
          setContour(closed ? drag.pts.slice(0, -1) : drag.pts.slice(), closed, 'free');
        }
      }
      drag = null;
    };
    sCv.addEventListener('pointerup', endDrag);
    sCv.addEventListener('pointercancel', endDrag);
    sCv.addEventListener('pointerleave', () => { if (!drag) hoverS = null; });
    sCv.addEventListener('wheel', e => { e.preventDefault(); const [px, py] = posOf(sCv, e); zoom(sView, sCv, Math.exp(e.deltaY * 0.0015), px, py); dirty = true; }, { passive: false });
    // L-plane: drag to pan, wheel to zoom (turns auto-fit off)
    let lDrag = null;
    lCv.addEventListener('pointerdown', e => { lCv.setPointerCapture(e.pointerId); lDrag = posOf(lCv, e); });
    lCv.addEventListener('pointermove', e => {
      if (!lDrag) return;
      const p = posOf(lCv, e), t = xf(lCv, lView);
      lView.cx -= (p[0] - lDrag[0]) / t.sc; lView.cy += (p[1] - lDrag[1]) / t.sc; lDrag = p;
      lAuto = false; chkAuto.checked = false;
    });
    lCv.addEventListener('pointerup', () => { lDrag = null; dirty = true; });
    lCv.addEventListener('wheel', e => { e.preventDefault(); const [px, py] = posOf(lCv, e); zoom(lView, lCv, Math.exp(e.deltaY * 0.0015), px, py); lAuto = false; chkAuto.checked = false; dirty = true; }, { passive: false });

    function togglePlay() {
      if (!contour) return;
      playing = !playing; btnPlay.textContent = playing ? 'Pause' : 'Play';
      if (playing && tr >= 1) tr = 0;
    }
    document.addEventListener('keydown', e => {
      if (CS.isTyping(e)) return;
      const k = e.key.toLowerCase();
      if (e.key === ' ') togglePlay();
      else if (k === 'n') setNyquist();
      else if (k === 'c' || e.key === 'Delete' || e.key === 'Backspace') clear();
      else if (k === 'f') { fitS(); lAuto = true; chkAuto.checked = true; }
      else return;
      e.preventDefault();
    });

    // ---- drawing ----
    function tokens() {
      const c = CS.colorsNow(), g = n => getComputedStyle(document.documentElement).getPropertyValue(n).trim();
      c.map = g('--map') || '#7a3fb0'; c.zero = c.out; c.poleC = c.part; c.bg = g('--bg');
      return c;
    }
    function begin(cv, ctx) {
      const r = CS.dpr();
      ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, cv.width, cv.height); ctx.scale(r, r);
    }
    function grid(ctx, t, v, colors, labels, ticks) {
      const [x0, y1] = t.inv(0, 0), [x1, y0] = t.inv(t.w, t.h);
      ctx.lineWidth = 1; ctx.font = '11px ' + colors.mono; ctx.fillStyle = colors.muted;
      if (ticks) {
        const n = Math.max(3, Math.round(Math.min(t.w, t.h) / 70));
        const st = CS.niceTicks(-v.half, v.half, n), d = st.length > 1 ? st[1] - st[0] : 1;
        ctx.strokeStyle = colors.grid; ctx.beginPath();
        for (let x = Math.ceil(x0 / d) * d; x <= x1; x += d) { ctx.moveTo(t.X(x), 0); ctx.lineTo(t.X(x), t.h); }
        for (let y = Math.ceil(y0 / d) * d; y <= y1; y += d) { ctx.moveTo(0, t.Y(y)); ctx.lineTo(t.w, t.Y(y)); }
        ctx.stroke();
        const ax = Math.min(Math.max(t.Y(0), 8), t.h - 16), ay = Math.min(Math.max(t.X(0), 30), t.w - 8);
        ctx.textAlign = 'center'; ctx.textBaseline = 'top';
        for (let x = Math.ceil(x0 / d) * d; x <= x1; x += d) if (Math.abs(x) > d / 2) ctx.fillText(fmt(+x.toPrecision(6)), t.X(x), ax + 3);
        ctx.textAlign = 'right'; ctx.textBaseline = 'middle';
        for (let y = Math.ceil(y0 / d) * d; y <= y1; y += d) if (Math.abs(y) > d / 2) ctx.fillText(fmt(+y.toPrecision(6)), ay - 4, t.Y(y));
      }
      ctx.strokeStyle = colors.muted; ctx.beginPath();
      ctx.moveTo(0, t.Y(0)); ctx.lineTo(t.w, t.Y(0)); ctx.moveTo(t.X(0), 0); ctx.lineTo(t.X(0), t.h); ctx.stroke();
      ctx.font = 'italic 14px ' + colors.body; ctx.fillStyle = colors.fg;
      const yl = Math.min(Math.max(t.Y(0), 20), t.h - 6), xl = Math.min(Math.max(t.X(0), 10), t.w - 30);
      sub(ctx, labels[0][0], labels[0][1], t.w - 22, yl - 8);
      sub(ctx, labels[1][0], labels[1][1], xl + 6, 58);
    }
    function sub(ctx, a, b, x, y) {   // "L" with subscript "x"
      ctx.textAlign = 'left'; ctx.textBaseline = 'alphabetic';
      ctx.fillText(a, x, y);
      if (b) { const w = ctx.measureText(a).width, f = ctx.font; ctx.font = f.replace(/\d+px/, '10px'); ctx.fillText(b, x + w, y + 4); ctx.font = f; }
    }
    const clampPx = v => Math.max(-1e5, Math.min(1e5, v));
    function path(ctx, pts, X, Y, brk) {
      ctx.beginPath();
      let pen = false;
      for (let i = 0; i < pts.length; i++) {
        const p = pts[i];
        if (!p || (brk && brk[i])) pen = false;
        if (!p) continue;
        const x = clampPx(X(p[0])), y = clampPx(Y(p[1]));
        pen ? ctx.lineTo(x, y) : ctx.moveTo(x, y); pen = true;
      }
      ctx.stroke();
    }
    function arrowHead(ctx, x, y, dx, dy, color, size = 9) {
      const L = Math.hypot(dx, dy); if (!(L > 0)) return;
      const ux = dx / L, uy = dy / L;
      ctx.fillStyle = color; ctx.beginPath();
      ctx.moveTo(x + ux * size, y + uy * size);
      ctx.lineTo(x - ux * size * 0.6 - uy * size * 0.6, y - uy * size * 0.6 + ux * size * 0.6);
      ctx.lineTo(x - ux * size * 0.6 + uy * size * 0.6, y - uy * size * 0.6 - ux * size * 0.6);
      ctx.closePath(); ctx.fill();
    }
    function arrows(ctx, pts, T, X, Y, color, brk) {   // direction marks at 1/8, 3/8, 5/8, 7/8 of the way
      for (const f of [0.125, 0.375, 0.625, 0.875]) {
        const i = idxAt(T, f);
        let j = i + 1;
        while (j < pts.length && pts[j] && pts[i] && Math.hypot(X(pts[j][0]) - X(pts[i][0]), Y(pts[j][1]) - Y(pts[i][1])) < 4) j++;
        if (j >= pts.length || !pts[i] || !pts[j] || (brk && brk.slice(i + 1, j + 1).some(Boolean))) continue;
        const x = X(pts[i][0]), y = Y(pts[i][1]);
        if (Math.abs(x) > 1e4 || Math.abs(y) > 1e4) continue;
        arrowHead(ctx, x, y, X(pts[j][0]) - x, Y(pts[j][1]) - y, color, 10);
      }
    }
    function idxAt(T, f) { let lo = 0, hi = T.length - 1; while (hi - lo > 1) { const m = (lo + hi) >> 1; if (T[m] <= f) lo = m; else hi = m; } return lo; }
    function title(ctx, text, note, colors) {
      ctx.textAlign = 'left'; ctx.textBaseline = 'top';
      ctx.font = '12px ' + colors.body;
      const wn = note ? ctx.measureText(note).width : 0;
      ctx.font = '700 13px ' + colors.body;
      ctx.globalAlpha = 0.85; ctx.fillStyle = colors.panel;
      ctx.fillRect(4, 4, Math.max(ctx.measureText(text).width, wn) + 12, note ? 38 : 22); ctx.globalAlpha = 1;
      ctx.fillStyle = colors.fg; ctx.fillText(text, 10, 8);
      if (note) { ctx.font = '12px ' + colors.body; ctx.fillStyle = colors.muted; ctx.fillText(note, 10, 26); }
    }
    function markRoot(ctx, x, y, zero, colors) {
      ctx.lineWidth = 2.2;
      if (zero) { ctx.strokeStyle = colors.zero; ctx.fillStyle = colors.panel; ctx.beginPath(); ctx.arc(x, y, 5.5, 0, TAU); ctx.fill(); ctx.stroke(); }
      else { ctx.strokeStyle = colors.poleC; const s = 5.5; ctx.beginPath(); ctx.moveTo(x - s, y - s); ctx.lineTo(x + s, y + s); ctx.moveTo(x + s, y - s); ctx.lineTo(x - s, y + s); ctx.stroke(); }
    }
    function dot(ctx, x, y, r, fill, stroke) { ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); if (fill) { ctx.fillStyle = fill; ctx.fill(); } if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = 2; ctx.stroke(); } }

    function drawS(colors, ti) {
      begin(sCv, sCtx);
      const ctx = sCtx, t = xf(sCv, sView);
      ctx.fillStyle = colors.unstableBg; ctx.fillRect(Math.max(0, t.X(0)), 0, t.w, t.h);
      grid(ctx, t, sView, colors, [['σ', ''], ['jω', '']], true);
      if (img && contour && ti !== null) {   // phasors from every root to the moving point
        const s0 = img.S[ti];
        ctx.lineWidth = 1.5; ctx.setLineDash([5, 4]);
        img.rootsAll.forEach(r => {
          ctx.strokeStyle = r.zero ? colors.zero : colors.poleC; ctx.globalAlpha = 0.75;
          ctx.beginPath(); ctx.moveTo(t.X(r.z[0]), t.Y(r.z[1])); ctx.lineTo(clampPx(t.X(s0[0])), clampPx(t.Y(s0[1]))); ctx.stroke();
        });
        ctx.setLineDash([]); ctx.globalAlpha = 1;
      }
      if (contour) {
        ctx.strokeStyle = colors.map; ctx.lineWidth = 2.5; ctx.lineJoin = 'round';
        path(ctx, contour.closed ? contour.pts.concat([contour.pts[0]]) : contour.pts, t.X, t.Y);
        if (img) {
          arrows(ctx, img.S, img.T, t.X, t.Y, colors.map);
          const p = img.S[0]; dot(ctx, t.X(p[0]), t.Y(p[1]), 4.5, colors.panel, colors.map);
        }
      }
      if (Lsys) { Lsys.zeros.forEach(z => markRoot(ctx, t.X(z[0]), t.Y(z[1]), true, colors)); Lsys.poles.forEach(p => markRoot(ctx, t.X(p[0]), t.Y(p[1]), false, colors)); }
      if (img && ti !== null) { const s0 = img.S[ti]; dot(ctx, clampPx(t.X(s0[0])), clampPx(t.Y(s0[1])), 6, colors.alert, colors.panel); }
      if (hoverS && !drag) dot(ctx, t.X(hoverS[0]), t.Y(hoverS[1]), 4, null, colors.muted);
      title(ctx, 's-plane', contour ? null : 'Draw a curve or a contour here', colors);
      if (hoverS && Lsys) {
        const L = Lof(hoverS);
        ctx.font = '12px ' + colors.mono; ctx.fillStyle = colors.muted; ctx.textAlign = 'left'; ctx.textBaseline = 'bottom';
        ctx.fillText('s = ' + fmtC(hoverS) + '  →  L(s) = ' + (fin(L) ? fmtC(L) : '∞'), 10, t.h - 8);
      }
    }
    function drawL(colors, ti) {
      begin(lCv, lCtx);
      const ctx = lCtx;
      if (lAuto && lTarget) {   // ease toward the fitted view
        const a = 0.2;
        lView.cx += a * (lTarget.cx - lView.cx); lView.cy += a * (lTarget.cy - lView.cy);
        lView.half *= (lTarget.half / lView.half) ** a;
      }
      const t = xf(lCv, lView);
      grid(ctx, t, lView, colors, [['L', 'x'], ['L', 'y']], scale === 'linear');
      if (scale === 'log') {   // magnitude circles
        ctx.font = '11px ' + colors.mono; ctx.textAlign = 'left'; ctx.textBaseline = 'bottom';
        [[0, '1'], [1, '10'], [2, '100'], [3, '1000'], [4, '10⁴'], [6, '10⁶']].forEach(([e, lbl]) => {
          const rc = 1 + e * Math.LN10;
          if (rc * t.sc > 4 * Math.max(t.w, t.h)) return;
          ctx.strokeStyle = colors.grid; ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(t.X(0), t.Y(0), rc * t.sc, 0, TAU); ctx.stroke();
          ctx.fillStyle = colors.muted; ctx.fillText('|L|=' + lbl, t.X(0) + rc * t.sc * 0.71 + 3, t.Y(0) - rc * t.sc * 0.71);
        });
      }
      if (chkUnit.checked) { ctx.strokeStyle = colors.muted; ctx.setLineDash([5, 4]); ctx.lineWidth = 1.2; ctx.beginPath(); ctx.arc(t.X(0), t.Y(0), t.sc, 0, TAU); ctx.stroke(); ctx.setLineDash([]); }
      // the critical point -1
      ctx.strokeStyle = colors.alert; ctx.lineWidth = 2; const mx = t.X(-1), my = t.Y(0);
      ctx.beginPath(); ctx.moveTo(mx - 6, my); ctx.lineTo(mx + 6, my); ctx.moveTo(mx, my - 6); ctx.lineTo(mx, my + 6); ctx.stroke();
      ctx.font = '12px ' + colors.mono; ctx.fillStyle = colors.alert; ctx.textAlign = 'center'; ctx.textBaseline = 'top'; ctx.fillText('−1', mx, my + 8);
      if (img) {
        ctx.strokeStyle = colors.map; ctx.lineWidth = 2.5; ctx.lineJoin = 'round';
        path(ctx, img.P, t.X, t.Y, img.brk);
        arrows(ctx, img.P, img.T, t.X, t.Y, colors.map, img.brk);
        const p = img.P[0]; if (p) dot(ctx, clampPx(t.X(p[0])), clampPx(t.Y(p[1])), 4.5, colors.panel, colors.map);
        if (ti !== null && img.P[ti]) {   // traced part, phasor from the counting point
          ctx.strokeStyle = colors.alert; ctx.globalAlpha = 0.35; ctx.lineWidth = 5;
          path(ctx, img.P.slice(0, ti + 1), t.X, t.Y, img.brk.slice(0, ti + 1)); ctx.globalAlpha = 1;
          const q = img.P[ti], x = clampPx(t.X(q[0])), y = clampPx(t.Y(q[1])), x0 = t.X(center), y0 = t.Y(0);
          ctx.strokeStyle = colors.fg; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x, y); ctx.stroke();
          arrowHead(ctx, x, y, x - x0, y - y0, colors.fg, 0);
          dot(ctx, x, y, 6, colors.alert, colors.panel);
        }
      }
      if (hoverS && Lsys && !drag) { const q = plotPt(Lof(hoverS)); if (q) dot(ctx, t.X(q[0]), t.Y(q[1]), 4, null, colors.muted); }
      title(ctx, 'L-plane', (kGain === 1 ? 'image of the contour, L(s)' : 'image of the contour, ' + fmt(kGain) + '·L(s)') + (scale === 'log' ? ', compressed |L|' : ''), colors);
      if (img && img.brk.some(Boolean)) {
        ctx.font = '12px ' + colors.body; ctx.fillStyle = colors.alert; ctx.textAlign = 'left'; ctx.textBaseline = 'bottom';
        ctx.fillText(scale === 'log' ? 'The image goes through infinity (pole on the contour).' : 'The image goes to infinity (pole on the contour): try the compressed scale.', 10, t.h - 8);
      }
    }
    function drawPhase(colors, ti) {
      begin(phCv, phCtx);
      const ctx = phCtx, r = phCv.getBoundingClientRect(), w = r.width, h = r.height;
      const L = 56, Rm = 12, T = w > 640 ? 26 : 40, B = 24;
      const lbl = '∠(1 + L(s))';
      ctx.font = '700 13px ' + colors.body; ctx.fillStyle = colors.fg; ctx.textAlign = 'left'; ctx.textBaseline = 'top';
      ctx.fillText('Phase ' + lbl + ' along the contour (unwrapped)', L, 6);
      if (!img) return;
      const ph = img.phase, f = ph.filter(Number.isFinite);
      if (!f.length) return;
      const p0 = f[0];
      let lo = Math.min(...f), hi = Math.max(...f);
      lo = Math.min(lo, p0 - 90); hi = Math.max(hi, p0 + 90);
      const pad = 0.08 * (hi - lo); lo -= pad; hi += pad;
      const X = v => L + v * (w - L - Rm), Y = v => T + (hi - v) / (hi - lo) * (h - T - B);
      ctx.font = '11px ' + colors.mono; ctx.lineWidth = 1;
      // lines at the start value + k*360
      for (let k = Math.ceil((lo - p0) / 360); p0 + k * 360 <= hi; k++) {
        const v = p0 + k * 360;
        ctx.strokeStyle = k === 0 ? colors.muted : colors.grid; ctx.setLineDash(k === 0 ? [] : [5, 4]);
        ctx.beginPath(); ctx.moveTo(L, Y(v)); ctx.lineTo(w - Rm, Y(v)); ctx.stroke(); ctx.setLineDash([]);
        ctx.fillStyle = colors.muted; ctx.textAlign = 'right'; ctx.textBaseline = 'middle';
        ctx.fillText((k > 0 ? '+' : k < 0 ? '−' : '') + (k ? Math.abs(k) * 360 + '°' : 'start'), L - 6, Y(v));
      }
      ctx.textAlign = 'center'; ctx.textBaseline = 'top'; ctx.fillStyle = colors.muted;
      ctx.fillText('start', X(0), h - B + 5); ctx.fillText('end', X(1), h - B + 5); ctx.fillText('position along the contour', (L + w - Rm) / 2, h - B + 5);
      ctx.strokeStyle = colors.map; ctx.lineWidth = 2;
      path(ctx, ph.map((v, i) => Number.isFinite(v) ? [img.T[i], v] : null), X, Y, img.brk);
      if (ti !== null && Number.isFinite(ph[ti])) dot(ctx, X(img.T[ti]), Y(ph[ti]), 5, colors.alert, colors.panel);
      const net = ph[ph.length - 1] - p0;
      if (Number.isFinite(net) && img.closed) {
        const wide = w > 640;
        ctx.font = '12px ' + colors.body; ctx.fillStyle = colors.muted; ctx.textAlign = wide ? 'right' : 'left'; ctx.textBaseline = 'top';
        ctx.fillText('net change ' + (net >= 0 ? '+' : '−') + Math.abs(net).toFixed(0) + '°  (' + (img.wind === null ? '?' : (net / 360).toFixed(0)) + ' turns, + = counterclockwise)', wide ? w - Rm : L, wide ? 6 : 22);
      }
    }
    function drawTracerInfo(ti) {
      if (!img || ti === null) { trBox.textContent = contour ? '' : 'Draw a contour, then press Play.'; return; }
      const s0 = img.S[ti], L0 = img.L[ti];
      const lines = ['s = ' + fmtC(s0), 'L(s) = ' + (fin(L0) ? fmtC(L0) : '∞')];
      if (fin(L0)) lines.push('|L| = ' + fmt(cabs(L0)) + ',  ∠L = ' + (carg(L0) * 180 / Math.PI).toFixed(1) + '°');
      if (img.rootsAll.length && img.rootsAll.length <= 10) {
        lines.push('Net turn of each phasor so far:');
        let tot = 0;
        img.rootsAll.forEach(r => {
          const d = (r.ang[ti] - r.ang[0]) * 180 / Math.PI;
          tot += r.zero ? d : -d;
          lines.push('  ' + (r.zero ? 'zero ' : 'pole ') + fmtC(r.z).padEnd(12) + (d >= 0 ? ' +' : ' −') + Math.abs(d).toFixed(0) + '°');
        });
        lines.push('  ∠L: zeros − poles = ' + (tot >= 0 ? '+' : '−') + Math.abs(tot).toFixed(0) + '°');
      }
      trBox.textContent = lines.join('\n');
    }

    // ---- loop ----
    let last = performance.now();
    function frame(now) {
      const dtw = Math.min((now - last) / 1000, 0.05); last = now;
      if (dirty) compute();
      if (playing && img) { tr += dtw / 10; if (tr >= 1) { tr = 1; playing = false; btnPlay.textContent = 'Play'; } slT.value = tr; }
      const ti = img ? idxAt(img.T, Math.min(tr, 1)) : null;
      const colors = tokens();
      drawS(colors, ti); drawL(colors, ti); drawPhase(colors, ti); drawTracerInfo(ti);
      requestAnimationFrame(frame);
    }
    setTool('draw');
    requestAnimationFrame(() => { init(); if (lTarget) lView = Object.assign({}, lTarget); requestAnimationFrame(frame); });

    // for tests
    window.NyquistDemo = { state: () => ({ img, contour, Lsys, center, kGain, clRoots, sView }), setL: str => { lInput.value = str; applyText(); }, setNyquist, setK, compute: () => compute() };
  }

  window.NyquistSim = { run };
})();
