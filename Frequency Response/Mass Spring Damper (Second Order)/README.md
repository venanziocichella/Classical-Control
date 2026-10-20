# Mass Spring Damper (second order, resonant low-pass)

A mass on a spring and a damper, pushed by a sinusoidal force: `m ẍ + c ẋ + k x = F(t)`. To compare input and output in the same units, the input is shown as the **static deflection** `F(t)/k` (where the mass would sit if the force changed very slowly; the dashed "ghost" block). Then

```
G(s) = X(s)/(F(s)/k) = ωn²/(s² + 2ζωn s + ωn²),   ωn = √(k/m) = 3.16 rad/s,  ζ = c/(2√(km))
```

Run:

```matlab
FR_MSD_Demo
```

The animation shows the wall, spring, damper and mass, the force arrow, and the ghost block at F/k.

## What to say in class

1. **Slow forcing (0.1 × ωn).** The mass follows the ghost block: |G| ≈ 1, phase ≈ 0°. The spring does all the work.
2. **At ωn (resonance).** With small damping the mass swings **much more** than the ghost (|G| = 1/(2ζ) = 5 for ζ = 0.1) and lags by exactly **90°**: *amplified*. Increase ζ and the peak goes down. For ζ ≥ 1/√2 there is no amplification at any frequency.
3. **Fast forcing (10 × ωn).** The mass hardly moves (inertia dominates, −40 dB/decade) and moves **opposite** to the force (−180°): *attenuated*.
4. Amplification happens for ω < ωn√(2 − 4ζ²); the demo prints this boundary on the Bode plot.
5. A real transient is visible after every change (lightly damped: it takes about 4/(ζωn) ≈ 13 s to settle). Use the 5× or 10× speed.

## Controls

- **Input frequency ω**: log slider. The readout gives ω in rad/s, the frequency in Hz and the period. The preset buttons jump to 0.1×, 1× and 10× the corner (or natural) frequency, and the Up/Down keys move ω by a third of an octave.
- **Amplitude A** of the input sinusoid.
- **System parameter** (τ or ζ): the Bode plot updates live.
- **Speed**: from 0.1× (slow motion, for fast inputs) to 10× (fast forward, for slow inputs or long transients).
- **Pause** (Space) and **Reset** (R).

## What is on the screen

- **Animation** of the mechanism, driven by the simulated motion.
- **Time plot**: input (gray) and output (blue) on the same axes. Once the response is steady, a red marker shows the time shift Δt between an input peak and the matching output peak.
- **Bode plot**: magnitude (dB) and phase, with a red dot at the current ω and a dashed line at the corner/natural frequency. Above 0 dB the input is amplified, below 0 dB it is attenuated.
- **Verdict and numbers**: AMPLIFIED ×|G| or ATTENUATED ×|G|. The theoretical |G(jω)| (absolute and in dB) and ∠G(jω) are shown next to the values measured from the simulation. The demo fits a sinusoid to the last whole periods of the response; until the transient has died out it says "settling...".

The simulation integrates the ODE exactly (zero-order-hold discretization of the state-space model) with a persistent state. When you change ω or a parameter you therefore see a real transient, which then settles to the steady-state sinusoid predicted by G(jω).

## Requirements

Base MATLAB R2021a or newer (uifigure). No toolboxes needed.
