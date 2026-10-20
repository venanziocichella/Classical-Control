# Frequency Response: the muffled song

A classroom demo for Chapter 7 (frequency response). A drum'n'bass / jungle
track plays in a loop through a filter G(s), and the students *hear* the Bode
plot: move the corner frequency down and the hats and cymbals disappear while
the sub-bass stays. The song sounds as if it were playing behind a wall.

## Files

| File | What it is |
| --- | --- |
| `FR_Muffled_Song_Demo.m` | The demo (a uifigure app built in code). Run this. |
| `FR_Make_Jungle_Track.m` | Synthesizes the original jungle loop (no samples, no copyrighted music) and writes `jungle_loop.wav`. |
| `FR_Filter_Coeffs.m` | G(s) and its discrete version (Tustin/bilinear with prewarping at the corner frequency, identical to `c2d(...,'tustin')` with `PrewarpFrequency`). |
| `jungle_loop.wav` | The synthesized track: 22.6 s, 170 BPM, 44.1 kHz. It is recreated automatically if you delete it. |

## How to run

```matlab
FR_Muffled_Song_Demo
```

- **Filter**: low-pass `1/(τs+1)`, high-pass `τs/(τs+1)`, or resonant
  `ωn²/(s²+2ζωn s+ωn²)` (with a ζ slider).
- **Corner frequency** `fc = 1/(2πτ)`: log slider from 50 Hz to 15 kHz,
  plus preset buttons (15 kHz, 2 kHz, 500 Hz, 150 Hz). Both `fc` and `τ` are shown.
- **Bypass** plays the original, so you can A/B compare.
- **Volume**, with a peak limiter so the output never clips (useful with the
  resonant filter at small ζ).
- **Load song...** plays any audio file you have (wav, mp3, m4a, flac, ...).
  You can also set `songFile` at the top of `FR_Muffled_Song_Demo.m`.
- **Reset song** (key `R`) jumps back to the start of the song; the filter settings stay as they are.
- Keys: `Space` play/pause, `R` reset song, `B` bypass, `Up`/`Down` move `fc` by 1/3 octave,
  `1`/`2`/`3` low-pass / high-pass / resonant.

Top plot: `|G(jω)|` in dB versus frequency, with the corner frequency marked
and the −3 dB level dotted. Bottom plot: the live spectrum of the music before
(gray) and after (blue) the filter.

## What to say in class

1. Start with bypass on, then switch to the low-pass at 15 kHz: nothing changes.
   *The filter only acts above its corner frequency.*
2. Slide `fc` down to 2 kHz, then 500 Hz, then 150 Hz. The cymbals go first,
   then the snare, then the chords. Only the kick and the sub-bass survive.
   In the bottom plot the blue curve peels away from the gray one above `fc`.
3. **The pitch never changes, only the amplitude.** A linear system does not
   create new frequencies: each sinusoid comes out at the same frequency,
   scaled by `|G(jω)|` and shifted by `∠G(jω)`.
4. Above the corner the gain falls by **−20 dB per decade** (a factor of 10 in
   amplitude for every factor of 10 in frequency). At the corner,
   `ω = 1/τ`, the gain is −3 dB.
5. Switch to the high-pass: now the bass disappears and the song turns thin and
   "tinny" (a phone speaker). The same corner, the mirror-image Bode plot.
6. Resonant mode with small ζ (about 0.05): one band of notes rings and booms.
   That is the resonant peak `M_r ≈ 1/(2ζ)` near `ωn`. Raise ζ and the ringing goes away.

## Requirements

- MATLAB R2021a or newer (uifigure, LaTeX in uiaxes).
- **Audio Toolbox** (`audioDeviceWriter`) for real-time audio: the sound
  changes while you drag the slider.
- Without the Audio Toolbox the demo still works. It re-filters the whole
  song and plays it with `audioplayer`, so the sound changes when you
  *release* a control rather than while you drag it. The panel tells you which
  mode is active.
- No other toolboxes are needed. The Control System Toolbox is not required;
  `c2d` is only mentioned in the comments for comparison.

## How the real-time filter works

The song is processed in frames of 1024 samples (about 23 ms). Each frame goes
through `filter(b, a, x, zi)`, and the filter state `zi` is carried from frame
to frame, so the output is continuous. When the slider moves, the corner
frequency glides to the new value on a logarithmic scale over a few frames,
and the coefficients are recomputed every frame. Bypass is a short crossfade.
None of these changes produce clicks.
