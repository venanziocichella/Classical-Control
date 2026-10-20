# Servo (first order, low-pass)

A DC motor speed servo. The input is the armature voltage `v(t) = A sin(ωt)` and the output is the shaft speed `ω_m(t)`. Neglecting the electrical dynamics, the motor is

```
G(s) = Ω_m(s)/V(s) = K/(τs + 1),    K = 5 rad/s per V,  τ = 0.2 s  (editable)
```

Run:

```matlab
FR_Servo_Demo
```

The animation shows the motor and a disk on its shaft (the red needle is the shaft angle, the integral of the speed), plus two bar gauges for the voltage and the speed.

## What to say in class

1. **Slow input (0.1 × 1/τ).** The speed follows the voltage, in phase, and is **5 times larger** (|G| ≈ K = 5, +14 dB): *amplified*.
2. **At the corner (ω = 1/τ = 5 rad/s).** |G| = K/√2 ≈ 3.5 (−3 dB from the DC gain) and the speed lags by **45°**. On the time plot you can see the delay Δt between the peaks.
3. **Fast input (10 × 1/τ).** The rotor inertia cannot keep up. The speed is much smaller and lags by almost **90°**.
4. **Amplified or attenuated?** Because K > 1, the motor amplifies sinusoids below the crossover ω = √(K²−1)/τ ≈ 24.5 rad/s, where |G| = 1 (0 dB), and attenuates them above it. The pitch never changes: the output is a sinusoid at **the same frequency**, only scaled by |G(jω)| and shifted by ∠G(jω).
5. Change τ: a larger τ (a heavier rotor) moves the corner to the left.

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
