/* song.js - the muffled song (port of FR_Muffled_Song_Demo.m, FR_Filter_Coeffs.m
 * and FR_Make_Jungle_Track.m). Needs engine.js (ControlSim helpers).
 * A song plays in a loop through G(s) (low-pass, high-pass or resonant),
 * discretized with Tustin + prewarping at fc, sample by sample in an
 * AudioWorklet (ScriptProcessor where AudioWorklet is missing).
 */
(function () {
  'use strict';
  const CS = window.ControlSim, el = CS.el;

  // ---------------------------------------------------------------------
  // Audio core: the same code runs in the AudioWorklet and in the fallback.
  // Keep it self-contained (it is sent to the worklet as source text).
  // ---------------------------------------------------------------------
  function makeCore() {
    return function Core(fs) {
      let song = new Float32Array(0), pos = 0, playing = false;
      let mode = 'low', fcT = 15000, fcCur = 15000, zeta = 0.1, bypass = false, vol = 0.8;
      let b0 = 1, b1 = 0, b2 = 0, a1 = 0, a2 = 0, z1 = 0, z2 = 0, wMix = 1, gLim = 1;
      function coeffs() {
        // FR_Filter_Coeffs: Tustin with prewarping at fc
        const K = Math.tan(Math.PI * Math.min(fcCur, 0.45 * fs) / fs);
        if (mode === 'low') { b0 = b1 = K / (1 + K); b2 = 0; a1 = (K - 1) / (1 + K); a2 = 0; }
        else if (mode === 'high') { b0 = 1 / (1 + K); b1 = -b0; b2 = 0; a1 = (K - 1) / (1 + K); a2 = 0; }
        else {
          const d = 1 + 2 * zeta * K + K * K;
          b0 = K * K / d; b1 = 2 * b0; b2 = b0; a1 = 2 * (K * K - 1) / d; a2 = (1 - 2 * zeta * K + K * K) / d;
        }
      }
      coeffs();
      return {
        set(m) {
          if (m.song) { song = m.song; pos = 0; z1 = z2 = 0; }
          if (m.mode !== undefined && m.mode !== mode) { mode = m.mode; fcCur = fcT; z1 = z2 = 0; }
          if (m.fc !== undefined) fcT = m.fc;
          if (m.zeta !== undefined) zeta = m.zeta;
          if (m.bypass !== undefined) bypass = m.bypass;
          if (m.vol !== undefined) vol = m.vol;
          if (m.playing !== undefined) playing = m.playing;
          if (m.restart) { pos = 0; z1 = z2 = 0; }
          coeffs();
        },
        pos() { return [pos, song.length]; },
        process(out, inp, mix, n) {
          if (!playing || !song.length) { out.fill(0); inp.fill(0); mix.fill(0); return; }
          // smooth the corner frequency (log scale) so moving the slider does not click
          const fcNew = fcCur * (fcT / fcCur) ** (1 - 0.65 ** (n / 1024));
          if (Math.abs(Math.log(fcNew / fcCur)) > 1e-5) { fcCur = fcNew; coeffs(); }
          const target = bypass ? 0 : 1;
          let pk = 0;
          for (let i = 0; i < n; i++) {
            const x = song[pos]; pos = pos + 1 < song.length ? pos + 1 : 0;
            const yf = b0 * x + z1;                    // direct form II transposed
            z1 = b1 * x - a1 * yf + z2; z2 = b2 * x - a2 * yf;
            wMix += Math.max(-1 / 1024, Math.min(1 / 1024, target - wMix));   // crossfade bypass
            const m = wMix * yf + (1 - wMix) * x;
            inp[i] = x; mix[i] = m; out[i] = vol * m;
            pk = Math.max(pk, Math.abs(out[i]));
          }
          // peak limiter (as in the MATLAB demo)
          const g = Math.min(1, 0.98 / Math.max(pk, 1e-12)), gNew = Math.min(g, Math.min(1, gLim * 1.02 ** (n / 1024)));
          for (let i = 0; i < n; i++) out[i] *= gLim + (gNew - gLim) * (i + 1) / n;
          gLim = gNew;
          if (!isFinite(z1) || !isFinite(z2)) z1 = z2 = 0;
        }
      };
    };
  }

  // ---------------------------------------------------------------------
  // FR_Make_Jungle_Track: drum'n'bass / reggae-jungle loop, 170 BPM, 16 bars.
  // ---------------------------------------------------------------------
  function makeJungle(fs) {
    let seed = 3600;
    const rand = () => { seed = (seed + 0x6D2B79F5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
    const randn = () => Math.sqrt(-2 * Math.log(1 - rand())) * Math.cos(2 * Math.PI * rand());
    const noise = n => Float32Array.from({ length: n }, randn);
    const saw = ph => 2 * (ph / (2 * Math.PI) % 1) - 1;
    function biquad(x, type, fc, Q) {
      const w0 = 2 * Math.PI * fc / fs, al = Math.sin(w0) / (2 * Q), c = Math.cos(w0), a0 = 1 + al;
      const b = type === 'low' ? [(1 - c) / 2, 1 - c, (1 - c) / 2] : [(1 + c) / 2, -(1 + c), (1 + c) / 2];
      const [b0, b1, b2] = b.map(v => v / a0), a1 = -2 * c / a0, a2 = (1 - al) / a0;
      const y = new Float32Array(x.length); let z1 = 0, z2 = 0;
      for (let i = 0; i < x.length; i++) { const v = b0 * x[i] + z1; z1 = b1 * x[i] - a1 * v + z2; z2 = b2 * x[i] - a2 * v; y[i] = v; }
      return y;
    }
    const gen = (sec, f) => Float32Array.from({ length: Math.round(sec * fs) }, (_, n) => f(n));
    const bpm = 170, step = 60 / bpm / 4, nBars = 16, nSteps = 16 * nBars;
    const N = Math.round((nSteps * step + 1.5) * fs), y = new Float32Array(N);
    const add = (x, t0, g = 1) => { const n0 = Math.round(t0 * fs); for (let i = 0; i < x.length && n0 + i < N; i++) y[n0 + i] += g * x[i]; };
    // drum sounds
    const kick = (() => {
      let ph = 0;
      const tone = gen(0.35, n => { ph += 2 * Math.PI * (45 + 75 * Math.exp(-n / (0.03 * fs))) / fs; return Math.sin(ph) * Math.exp(-n / (0.12 * fs)); });
      const click = biquad(noise(tone.length).map((v, n) => v * Math.exp(-n / (0.002 * fs))), 'high', 2000, 0.7);
      return tone.map((v, n) => v + 0.3 * click[n]);
    })();
    const snareOf = bright => {
      const nz = biquad(noise(Math.round(0.25 * fs)), 'high', 1200, 0.7);
      return nz.map((v, n) => 0.6 * Math.sin(2 * Math.PI * 190 * n / fs) * Math.exp(-n / (0.04 * fs)) + bright * 0.8 * v * Math.exp(-n / (0.07 * fs)));
    };
    const hatOf = dec => biquad(biquad(noise(Math.round(5 * dec * fs)), 'high', 7000, 0.7), 'high', 7000, 0.7).map((v, n) => v * Math.exp(-n / (dec * fs)));
    const snare = snareOf(1), ghost = snareOf(0.6).map(v => 0.3 * v), hat = hatOf(0.035), ohat = hatOf(0.22);
    const ride = (() => {
      const ph = [3150, 4270, 5530, 6810, 8370].map(f => [f, 2 * Math.PI * rand()]);
      const nz = biquad(noise(Math.round(1.2 * fs)), 'high', 5000, 0.7);
      return nz.map((v, n) => (0.4 * ph.reduce((s, [f, p]) => s + Math.sin(2 * Math.PI * f * n / fs + p), 0) / 5 + 0.6 * v) * Math.exp(-n / (0.35 * fs)));
    })();
    const crash = biquad(noise(Math.round(1.6 * fs)), 'high', 4000, 0.7).map((v, n) => v * Math.exp(-n / (0.5 * fs)));
    // chopped "amen-style" break, 16 steps per bar
    const K = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0], Sn = [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0];
    const G = [0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1];
    const Kv = [1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0], Sv = [0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1];
    for (let bar = 0; bar < nBars; bar++) {
      const k = bar % 4 === 3 ? Kv : K, sn = bar % 4 === 3 ? Sv : Sn;
      for (let st = 1; st <= 16; st++) {
        const t0 = (bar * 16 + st - 1) * step;
        if (k[st - 1]) add(kick, t0);
        if (sn[st - 1]) add(snare, t0, 0.8);
        if (G[st - 1] && !sn[st - 1]) add(ghost, t0);
        if (st === 12) add(ohat, t0, 0.22); else add(hat, t0, 0.10 + 0.08 * (st % 2 === 1));
        if (st % 4 === 1 && bar >= 4) add(ride, t0, 0.10);
      }
      if (bar % 4 === 0) add(crash, bar * 16 * step, 0.30);
    }
    // bass: sub sine + detuned "reese" saws, two bars per root
    const roots = [41.20, 41.20, 49.00, 36.71, 41.20, 41.20, 55.00, 49.00];
    const bass = new Float32Array(N);
    for (let bar = 0; bar < nBars; bar++) {
      const f0 = roots[Math.floor(bar / 2) % roots.length];
      for (const st of [1, 7, 9, 15]) {
        const len = Math.round((st === 15 || st === 7 ? 2 : 6) * step * fs), n0 = Math.round((bar * 16 + st - 1) * step * fs);
        for (let n = 0; n < len && n0 + n < N; n++) {
          const env = Math.min(1, n / (0.004 * fs)) * Math.exp(-n / (0.9 * fs)) * Math.min(1, (len - n) / (0.01 * fs));
          const p = 2 * Math.PI * f0 * n / fs;
          bass[n0 + n] += env * (0.55 * Math.sin(p) + 0.18 * (saw(p) + saw(1.012 * p)));
        }
      }
    }
    biquad(bass, 'low', 180, 0.7).forEach((v, i) => { y[i] += v; });
    // reggae "skank": offbeat E minor stabs
    let stab = gen(0.12, n => [329.63, 392.00, 493.88, 659.26].reduce((s, f) =>
      s + Math.sign(Math.sin(2 * Math.PI * f * n / fs)) * 0.5 + Math.sin(2 * Math.PI * 2 * f * n / fs) * 0.3, 0) * Math.exp(-n / (0.035 * fs)));
    stab = biquad(stab, 'high', 250, 0.7);
    const sm = stab.reduce((m, v) => Math.max(m, Math.abs(v)), 0);
    for (let bar = 0; bar < nBars; bar++) for (const st of [3, 7, 11, 15]) add(stab, (bar * 16 + st - 1) * step, 0.24 / sm);
    // dub siren (bars 7 and 15) and air horn (bar 11)
    for (const bar of [7, 15]) {
      const nS = Math.round(8 * step * fs); let ph = 0;
      add(gen(8 * step, n => { ph += 2 * Math.PI * (900 + 500 * Math.sin(2 * Math.PI * 6 * n / fs) + 300 * n / nS) / fs; return Math.sin(ph) * Math.min(1, n / (0.02 * fs)) * Math.exp(-n / (1.2 * fs)); }),
        bar * 16 * step, 0.10);
    }
    const horn = gen(0.18, n => [466.16, 587.33, 698.46].reduce((s, f) => s + saw(2 * Math.PI * f * n / fs), 0) * Math.min(1, n / (0.005 * fs)) * Math.exp(-n / (0.12 * fs)));
    for (let k = 0; k < 3; k++) add(horn, (11 * 16 + 4 * k) * step, 0.05);
    // master: exact loop length, soft clip, normalize (0.9 peak as loadSong)
    const out = y.slice(0, Math.round(nSteps * step * fs)).map(v => Math.tanh(1.2 * v) / Math.tanh(1.2));
    return normalize(out);
  }
  function normalize(x) {
    const pk = x.reduce((m, v) => Math.max(m, Math.abs(v)), 0) || 1;
    return x.map(v => 0.9 * v / pk);
  }

  // ---------------------------------------------------------------------
  // Page
  // ---------------------------------------------------------------------
  const MODES = {
    low: { label: 'Low-pass   1/(τs + 1)', num: '1', den: 'τs + 1', slope: '−20 dB/decade', sym: 'fc' },
    high: { label: 'High-pass   τs/(τs + 1)', num: 'τs', den: 'τs + 1', slope: '+20 dB/decade', sym: 'fc' },
    res: { label: 'Resonant   ωn²/(s² + 2ζωn s + ωn²)', num: 'ωn²', den: 's² + 2ζωn s + ωn²', slope: '−40 dB/decade', sym: 'fn' }
  };
  const fmtHz = f => f >= 1000 ? +(f / 1000).toPrecision(3) + ' kHz' : +f.toPrecision(3) + ' Hz';
  const fmtTau = t => t >= 1e-3 ? +(1e3 * t).toPrecision(3) + ' ms' : +(1e6 * t).toPrecision(3) + ' µs';

  function run(cfg) {
    const root = document.getElementById(cfg.mount || 'app');
    let mode = 'low', fc = cfg.fc0 || 15000, zeta = cfg.zeta0 || 0.1, bypass = false, vol = 0.8, playing = false;
    let ctx = null, send = () => {}, anIn = null, anOut = null, songPos = [0, 0], songName = 'synthesized jungle loop';
    let pending = null;   // song waiting for the audio engine
    const specIn = new Float32Array(2048).fill(-200), specOut = new Float32Array(2048).fill(-200);

    // ---- DOM ----
    const bodeCv = el('canvas', { 'aria-label': 'Bode magnitude of G(s)' });
    const specCv = el('canvas', { 'aria-label': 'spectrum of the music before and after G(s)' });
    const selMode = el('select', { id: 'mode', class: 'cs-select', 'aria-label': 'Filter', onchange: e => setMode(e.target.value) },
      Object.entries(MODES).map(([k, m]) => el('option', { value: k, text: m.label })));
    const gBox = el('div', { class: 'cs-tf' });
    const lg = Math.log10;
    const slFc = el('input', { id: 'fc', class: 'cs-range', type: 'range', min: lg(50), max: lg(15000), step: 0.001, 'aria-label': 'Corner frequency' });
    slFc.addEventListener('input', () => setFc(10 ** +slFc.value));
    const lblFc = el('div', { class: 'fr-val' });
    const pre = el('div', { class: 'cs-row' }, [15000, 2000, 500, 150].map(f => el('button', { type: 'button', class: 'cs-btn', onclick: () => setFc(f) }, [fmtHz(f)])));
    const slZ = el('input', { id: 'zeta', class: 'cs-range', type: 'range', min: 0.02, max: 1, step: 0.01, value: zeta, 'aria-label': 'Damping ratio' });
    slZ.addEventListener('input', () => setZeta(+slZ.value));
    const lblZ = el('div', { class: 'fr-val' });
    const cbBy = el('input', { id: 'bypass', type: 'checkbox', onchange: e => setBypass(e.target.checked) });
    const slV = el('input', { id: 'vol', class: 'cs-range', type: 'range', min: 0, max: 1.5, step: 0.01, value: vol, 'aria-label': 'Volume' });
    slV.addEventListener('input', () => { vol = +slV.value; send({ vol }); });
    const btnPlay = el('button', { type: 'button', class: 'cs-btn cs-primary', onclick: () => togglePlay() }, ['Play']);
    const file = el('input', { type: 'file', accept: 'audio/*', hidden: '', onchange: e => loadFile(e.target.files[0]) });
    const lblSong = el('p', { class: 'cs-note' }), lblT = el('div', { class: 'cs-time' }), lblAudio = el('p', { class: 'cs-note' });

    const panel = el('aside', { class: 'cs-panel' }, [
      el('section', { class: 'cs-sec' }, [el('h2', { text: 'Filter' }), selMode, gBox]),
      el('section', { class: 'cs-sec' }, [el('h2', { class: 'plain', text: 'Corner frequency  fc = 1/(2πτ)' }), slFc, lblFc, pre]),
      el('section', { class: 'cs-sec' }, [el('h2', { class: 'plain', text: 'Damping ratio ζ  (resonant)' }), slZ, lblZ]),
      el('section', { class: 'cs-sec' }, [
        el('label', { class: 'cs-note', style: 'display:flex;gap:8px;align-items:center;color:var(--fg)' }, [cbBy, 'Bypass: play the original (B)']),
        el('label', { for: 'vol', class: 'cs-note', text: 'Volume' }), slV]),
      el('section', { class: 'cs-sec' }, [el('h2', { text: 'Song' }),
        el('div', { class: 'cs-row' }, [btnPlay,
          el('button', { type: 'button', class: 'cs-btn', onclick: () => restart() }, ['Reset song']),
          el('button', { type: 'button', class: 'cs-btn', onclick: () => file.click() }, ['Load song…']), file]),
        lblT, lblSong, lblAudio,
        el('p', { class: 'cs-note', text: 'Keys: Space play/pause, R reset song, B bypass, ↑/↓ move fc, 1/2/3 low-pass/high-pass/resonant. Use headphones or good speakers: a laptop speaker plays little below 150 Hz.' })])
    ]);
    root.append(el('div', { class: 'cs-grid' }, [
      el('div', { class: 'cs-main' }, [el('div', { class: 'fr-card' }, [bodeCv]), el('div', { class: 'fr-card' }, [specCv])]), panel]));
    const bctx = CS.setupCanvas(bodeCv), sctx = CS.setupCanvas(specCv);

    // ---- state changes ----
    function setMode(m) { mode = m; selMode.value = m; slZ.disabled = m !== 'res'; send({ mode }); refresh(); }
    function setFc(f) { fc = Math.min(Math.max(f, 50), 15000); slFc.value = lg(fc); send({ fc }); refresh(); }
    function setZeta(z) { zeta = z; slZ.value = z; send({ zeta }); refresh(); }
    function setBypass(v) { bypass = v; cbBy.checked = v; send({ bypass }); refresh(); }
    function restart() { send({ restart: true }); specIn.fill(-200); specOut.fill(-200); }
    async function togglePlay() {
      if (!ctx) { try { await startAudio(); } catch (err) { lblAudio.textContent = 'Cannot start audio: ' + err.message; return; } }
      playing = !playing;
      if (playing && ctx.state !== 'running') await ctx.resume();
      send({ playing }); btnPlay.textContent = playing ? 'Pause' : 'Play';
    }
    function refresh() {
      const M = MODES[mode];
      gBox.replaceChildren(el('span', { class: 'cs-lhs', text: 'G(s) =' }),
        el('span', { class: 'cs-frac' }, [el('span', { class: 'cs-num', text: M.num }), el('span', { class: 'cs-den', text: M.den })]));
      lblFc.textContent = (mode === 'res' ? 'fn = ' : 'fc = ') + fmtHz(fc) + '    τ = ' + fmtTau(1 / (2 * Math.PI * fc));
      lblZ.textContent = 'ζ = ' + zeta.toFixed(2) + (mode === 'res' ? '' : '   (used by the resonant filter only)');
      lblSong.textContent = 'Song: ' + songName;
    }
    function Gjf(f) {   // G(j 2 pi f), analog
      const s = 2 * Math.PI * f / (2 * Math.PI * fc);   // normalized: jω/ωc
      if (mode === 'low') return 1 / Math.hypot(1, s);
      if (mode === 'high') return s / Math.hypot(1, s);
      return 1 / Math.hypot(1 - s * s, 2 * zeta * s);
    }

    // ---- audio ----
    async function startAudio() {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) throw new Error('this browser has no Web Audio');
      try { ctx = new AC({ sampleRate: 44100 }); } catch (e) { ctx = new AC(); }
      const fs = ctx.sampleRate, split = ctx.createChannelSplitter(3);
      let node;
      try {
        const src = 'const Core = (' + makeCore.toString() + ')();\n' +
          'class P extends AudioWorkletProcessor {\n' +
          '  constructor() { super(); this.c = Core(sampleRate); this.k = 0; this.port.onmessage = e => this.c.set(e.data); }\n' +
          '  process(i, o) { const c = o[0]; this.c.process(c[0], c[1], c[2], c[0].length); if (++this.k % 32 === 0) this.port.postMessage(this.c.pos()); return true; }\n' +
          '}\nregisterProcessor("fr-song", P);';
        const url = URL.createObjectURL(new Blob([src], { type: 'application/javascript' }));
        await ctx.audioWorklet.addModule(url);
        node = new AudioWorkletNode(ctx, 'fr-song', { numberOfInputs: 0, numberOfOutputs: 1, outputChannelCount: [3] });
        node.port.onmessage = e => { songPos = e.data; };
        send = (m, tr) => node.port.postMessage(m, tr || []);
        lblAudio.textContent = 'Real-time audio: the filter runs sample by sample (AudioWorklet, ' + fs + ' Hz).';
      } catch (e) {    // e.g. file:// pages: blob worklets need an origin
        const core = makeCore()(fs);
        node = ctx.createScriptProcessor(1024, 1, 3);
        node.onaudioprocess = ev => { const b = ev.outputBuffer; core.process(b.getChannelData(0), b.getChannelData(1), b.getChannelData(2), b.length); songPos = core.pos(); };
        send = m => core.set(m);
        lblAudio.textContent = 'Real-time audio (ScriptProcessor fallback, ' + fs + ' Hz).';
      }
      node.connect(split);
      anIn = ctx.createAnalyser(); anOut = ctx.createAnalyser();
      for (const a of [anIn, anOut]) { a.fftSize = 4096; a.smoothingTimeConstant = 0.7; a.minDecibels = -140; }
      split.connect(ctx.destination, 0); split.connect(anIn, 1); split.connect(anOut, 2);
      send({ mode, fc, zeta, bypass, vol });
      if (!pending) { lblSong.textContent = 'Synthesizing the jungle loop…'; await new Promise(r => setTimeout(r, 30)); pending = makeJungle(44100); }
      setSong(pending, songName);
    }
    function setSong(x, name) {
      const fs = ctx.sampleRate;
      if (x.rate && x.rate !== fs) x = resample(x, x.rate, fs);
      else if (!x.rate && fs !== 44100) x = resample(x, 44100, fs);
      songName = name; pending = null;
      send({ song: x }, [x.buffer]); restart(); refresh();
    }
    function resample(x, f1, f2) {
      const n = Math.floor((x.length - 1) * f2 / f1) + 1, y = new Float32Array(n);
      for (let i = 0; i < n; i++) { const t = i * f1 / f2, k = Math.floor(t), a = t - k; y[i] = (1 - a) * x[k] + a * (x[Math.min(k + 1, x.length - 1)]); }
      return y;
    }
    async function loadFile(f) {
      if (!f) return;
      try {
        if (!ctx) await startAudio();
        const buf = await ctx.decodeAudioData(await f.arrayBuffer());
        const x = new Float32Array(buf.length);
        for (let c = 0; c < buf.numberOfChannels; c++) buf.getChannelData(c).forEach((v, i) => { x[i] += v / buf.numberOfChannels; });
        if (playing) togglePlay();      // new song: wait for Play
        setSong(normalize(x), f.name);
      } catch (err) { lblSong.textContent = 'Cannot read ' + f.name + ': ' + err.message; }
      file.value = '';
    }

    // ---- plots ----
    const F0 = 20, F1 = 20000;
    function axes(cv, c, lo, hi, step, yLabel, title) {
      const r = CS.dpr(), W = cv.width / r, H = cv.height / r, L = 56, R = 14, T = 30, B = 34;
      c.setTransform(r, 0, 0, r, 0, 0); c.clearRect(0, 0, W, H);
      const colors = CS.colorsNow();
      const X = f => L + (lg(f) - lg(F0)) / (lg(F1) - lg(F0)) * (W - L - R), Y = v => T + (hi - v) / (hi - lo) * (H - T - B);
      c.font = '11px ' + colors.mono; c.lineWidth = 1;
      for (let e = 1; e <= 4; e++) for (let m = 1; m < 10; m++) {
        const f = m * 10 ** e; if (f < F0 || f > F1) continue;
        c.strokeStyle = colors.grid; c.globalAlpha = m === 1 ? 1 : 0.5; c.beginPath(); c.moveTo(X(f), T); c.lineTo(X(f), H - B); c.stroke(); c.globalAlpha = 1;
      }
      c.fillStyle = colors.muted; c.textAlign = 'center'; c.textBaseline = 'top';
      [[20, '20'], [50, '50'], [100, '100'], [200, '200'], [500, '500'], [1e3, '1k'], [2e3, '2k'], [5e3, '5k'], [1e4, '10k'], [2e4, '20k']]
        .forEach(([f, s]) => c.fillText(s, X(f), H - B + 5));
      c.textAlign = 'right'; c.fillText('frequency f [Hz]', W - R, H - 14);
      c.textBaseline = 'middle';
      for (let v = lo; v <= hi; v += step) { c.strokeStyle = colors.grid; c.beginPath(); c.moveTo(L, Y(v)); c.lineTo(W - R, Y(v)); c.stroke(); c.fillStyle = colors.muted; c.fillText(String(v).replace('-', '−'), L - 6, Y(v)); }
      c.save(); c.translate(12, T + (H - T - B) / 2); c.rotate(-Math.PI / 2); c.textAlign = 'center'; c.fillText(yLabel, 0, 0); c.restore();
      c.font = '600 13px ' + colors.body; c.fillStyle = colors.fg; c.textAlign = 'left'; c.textBaseline = 'top'; c.fillText(title, L, 8);
      // corner
      c.strokeStyle = colors.alert; c.lineWidth = 1.5; c.setLineDash([6, 4]);
      c.beginPath(); c.moveTo(X(fc), T); c.lineTo(X(fc), H - B); c.stroke(); c.setLineDash([]);
      return { X, Y, W, H, L, R, T, B, colors };
    }
    function clipTo(c, a) { c.save(); c.beginPath(); c.rect(a.L, a.T, a.W - a.L - a.R, a.H - a.T - a.B); c.clip(); }
    function curve(c, pts, color, width, dash) {
      c.strokeStyle = color; c.lineWidth = width; c.setLineDash(dash || []); c.beginPath();
      pts.forEach(([x, y], k) => k ? c.lineTo(x, y) : c.moveTo(x, y)); c.stroke(); c.setLineDash([]);
    }
    function drawBode() {
      const M = MODES[mode];
      const a = axes(bodeCv, bctx, -60, 20, 10, '|G(jω)| [dB]', 'Bode magnitude:  G(s) = ' + M.num + ' / (' + M.den + ')'), c = bctx, col = a.colors;
      clipTo(c, a);
      curve(c, [[a.L, a.Y(-3)], [a.W - a.R, a.Y(-3)]], col.muted, 1, [2, 3]);
      const pts = [];
      for (let k = 0; k <= 500; k++) { const f = 10 * 2200 ** (k / 500); pts.push([a.X(f), a.Y(Math.max(20 * lg(Gjf(f)), -80))]); }
      curve(c, pts, col.out, 2.5, bypass ? [3, 4] : null);
      c.restore();
      c.font = '14px ' + col.mono; c.fillStyle = col.alert; c.textBaseline = 'top';
      const right = fc > 5000;
      c.textAlign = right ? 'right' : 'left'; c.fillText(M.sym + ' = ' + fmtHz(fc), a.X(fc) + (right ? -6 : 6), a.T + 6);
      c.fillStyle = col.fg; c.textAlign = 'left'; c.textBaseline = 'alphabetic';
      const xs = mode === 'high' ? a.X(25) : a.X(Math.min(Math.max(fc * 4, 400), 6000));
      c.fillText(M.slope, Math.min(xs, a.W - a.R - c.measureText(M.slope).width), a.Y(-45));
      if (bypass) { c.fillStyle = col.muted; c.textAlign = 'right'; c.fillText('bypassed', a.W - a.R - 4, a.Y(14)); }
    }
    function drawSpec() {
      const a = axes(specCv, sctx, -100, -10, 10, 'music spectrum [dB]', 'Music: original (gray) and after G(s) (blue)'), c = sctx, col = a.colors;
      if (anIn && playing) {
        const tmp = new Float32Array(anIn.frequencyBinCount);
        anIn.getFloatFrequencyData(tmp); specIn.set(tmp); anOut.getFloatFrequencyData(tmp); specOut.set(tmp);
      }
      const binHz = (ctx ? ctx.sampleRate : 44100) / 4096;
      const line = (sp, color, w) => {
        const pts = [];
        for (let k = 1; k < sp.length; k++) {
          const f = k * binHz; if (f < F0 * 0.9) continue; if (f > F1 * 1.05) break;
          let s = 0, n = 0; for (let j = Math.max(1, k - 2); j <= Math.min(sp.length - 1, k + 2); j++) { s += Math.max(sp[j], -200); n++; }
          pts.push([a.X(f), a.Y(s / n)]);
        }
        curve(c, pts, color, w);
      };
      clipTo(c, a); line(specIn, col.metal, 1); line(specOut, col.out, 1.6); c.restore();
      if (!playing) { c.font = '600 15px ' + col.body; c.fillStyle = col.muted; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText(ctx ? 'Paused' : 'Press Play to start the song', (a.L + a.W - a.R) / 2, (a.T + a.H - a.B) / 2); }
    }
    function frame() {
      drawBode(); drawSpec();
      const fs = ctx ? ctx.sampleRate : 44100, mmss = n => { const s = Math.floor(n / fs); return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0'); };
      lblT.textContent = songPos[1] ? mmss(songPos[0]) + ' / ' + mmss(songPos[1]) : '';
      requestAnimationFrame(frame);
    }

    document.addEventListener('keydown', e => {
      const k = e.key;
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      // a focused control keeps its own Space and arrow keys
      if (e.target.closest && e.target.closest('input, select, textarea, button') && (k === ' ' || k.startsWith('Arrow'))) return;
      if (k === ' ') { e.preventDefault(); togglePlay(); }
      else if (k === 'r' || k === 'R') restart();
      else if (k === 'b' || k === 'B') setBypass(!bypass);
      else if (k === 'ArrowUp') { e.preventDefault(); setFc(fc * 2 ** (1 / 3)); }
      else if (k === 'ArrowDown') { e.preventDefault(); setFc(fc / 2 ** (1 / 3)); }
      else if (k === '1') setMode('low'); else if (k === '2') setMode('high'); else if (k === '3') setMode('res');
    });
    setMode(mode); setFc(fc); setZeta(zeta);
    requestAnimationFrame(frame);
  }

  window.SongSim = { run, makeJungle, makeCore };
})();
