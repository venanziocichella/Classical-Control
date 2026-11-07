# Contour mapping (Cauchy's argument principle and Nyquist)

Two planes side by side: the **s-plane** (left), with the poles (×) and zeros (o)
of the mapping function L(s), and the **L-plane** (right), with axes L_x and L_y.
Draw a curve or a closed contour on the s-plane with the mouse: its image L(s)
is drawn on the L-plane while you draw.

Run:

```matlab
NYQ_Mapping_Demo
```

or open the browser version (no MATLAB): `Web/nyquist/contour-mapping.html`.

## Controls

- **L(s)**: type it like C(s) in the other demos (numbers, `s`, `+ - * / ^` and
  parentheses), e.g. `(s+1)/((s+2)^2+1)` or `(3+9/s)*(s^2-0.5*s+0.5)/(s^3-s^2-2*s+8)`.
  The same text works in MATLAB and in the browser. Or pick one of the
  examples of Chapter 9.
- **Gain k**: the L-plane shows k·L(s) (useful with the Nyquist contour: watch
  the plot grow until it encircles −1).
- **Tools**: *Draw* (freehand; the curve is closed when you let go, unless you
  untick the box), *Circle* and *Rectangle* (drag; traced clockwise as in the
  notes), *Move* (drag the contour across a pole or a zero, drag a pole or a
  zero itself, and L(s) follows; complex pairs stay conjugate; or drag the empty
  plane to pan). Mouse wheel: zoom.
- **Nyquist contour**: up the jω axis, indenting to the right of poles on it,
  and back along a large clockwise semicircle. **Reverse** flips the direction.
- **Count around**: the origin (Cauchy, N = Z − P with Z, P the zeros and poles
  of L inside) or −1 (Nyquist, Z = N + P with Z the zeros of 1 + kL inside).
  The demo counts the encirclements from the image and checks them against the
  poles and zeros inside the contour.
- **Moving point** (Play): a point runs along the contour; the phasors from the
  poles (orange) and zeros (blue) to the point are drawn, with the net turn of
  each one. At the end of the lap only the poles and zeros inside have turned
  by 360°.
- **Phase plot** (bottom): the unwrapped ∠L (or ∠(1 + L)) along the contour;
  its net change divided by 360° is the number of encirclements.
- **Compressed scale**: |L| > 1 is drawn at radius 1 + ln|L|, so the image stays
  on the screen when the contour passes near a pole (as for the integrator).

If the contour passes exactly through a pole or a zero, the image goes through
infinity (or the origin): the demo says so and does not count.

## What to try in class

1. *Mapping a contour*: a small circle through (s+2)/(s+1), then move it around.
2. *Squares through 2s+1 and s/(s+2)*: the angles at the corners are preserved.
3. *Cauchy*: drag a circle onto the zero of (s+1)/((s+2)²+1) (one clockwise
   encirclement) and then onto a pole (one counterclockwise).
4. *3 zeros, 3 poles*: one pole and three zeros inside, N_cw = 3 − 1 = 2.
   Press Play and watch the phasor table.
5. *Nyquist*: 50/((s+1)(s+2)(s+3)) is stable; raise k above 1.2 (K > 60) and the
   plot encircles −1 twice: two closed-loop poles in the RHP.
6. *Rocket with PI*: P = 2 unstable open-loop poles, two counterclockwise
   encirclements of −1, Z = 0: stable.

## Requirements

Base MATLAB R2021a or newer (uifigure). No toolboxes.
