# Spring Damper (first order with a zero at the origin, high-pass)

A spring and a damper (dashpot) **in series**. Your hand moves the end of the damper, `x_in(t) = A sin(ωt)`. The other end of the damper is a light plate held by a spring to the wall, and the plate position `x(t)` is the output. Force balance on the massless plate, `c (ẋ_in − ẋ) = k x`, gives

```
G(s) = X(s)/X_in(s) = τs/(τs + 1),    τ = c/k
```

Run:

```matlab
FR_SpringDamper_Demo
```

The animation shows the wall, spring, plate, damper cylinder (attached to the plate, with oil) and the piston rod held by the hand.

## Why this example

τs/(τs+1) needs an element that responds to the *rate* of the input. A dashpot in series with a spring is the simplest mechanical one: it is the mechanical twin of the RC high-pass filter, and it is how real devices **block slow motion and pass fast motion**. Examples are the "washout" in vehicle suspensions and motion simulators, and the shock-absorber coupling of a door closer: push slowly and nothing happens; push fast and it feels rigid.

## What to say in class

1. **Slow input (0.1 × 1/τ).** The damper offers almost no force, so it just **slides** and the plate barely moves: *blocked* (|G| ≈ ωτ, small). The small motion it does have **leads** the hand by almost **+90°**, because it is proportional to the hand's velocity.
2. **At the corner (ω = 1/τ).** |G| = 1/√2 (−3 dB) and the lead is **+45°**.
3. **Fast input (10 × 1/τ).** The damper has no time to slide and behaves like a **rigid rod**. The plate follows the hand almost exactly (|G| → 1, phase → 0°): *passes*.
4. |G| < 1 at every frequency, so this system **never amplifies**. It is the mirror image of the first-order low-pass: τs/(τs+1) = 1 − 1/(τs+1). The damper stroke x_in − x is exactly the low-pass part.
5. Change τ = c/k: a thicker oil (larger c) moves the corner to the left, so even slower motions get through.

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
