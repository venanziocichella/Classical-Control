# Browser demos

The MATLAB real-time demos as web pages, for students without MATLAB.
Open `index.html` (double-click works, or serve the folder, e.g. GitHub Pages).

- `routh-hurwitz/`, `root-locus/`: the 12 control examples. Type C(s) in the page
  (numbers, `s`, `+ - * / ^`, parentheses: the same text works in the MATLAB demos).
- `frequency-response/`: servo, spring-damper, mass-spring-damper, the muffled song.
- `nyquist/`: contour mapping. Type L(s) the same way as C(s), draw on the s-plane.

The pages are generated: edit `tools/pages_control.py`, `tools/pages_fr.py` or
`tools/pages_nyq.py`, then run `python3 Web/tools/make_pages.py`. Shared code:
`engine.js` (parser, simulation, panels), `fr.js` (frequency response),
`song.js` (muffled song audio), `nyquist.js` (contour mapping), `sim.css`.

The muffled song filters in an AudioWorklet when the page is served over http(s);
opened from disk it uses the older ScriptProcessor, which also works.
