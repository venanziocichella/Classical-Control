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
  The same text works in MATLAB and in the browser. The demo starts with
  L(s) = 50/((s+1)(s+2)(s+3)) and the Nyquist contour.
- **Gain k**: the L-plane shows k·L(s) (useful with the Nyquist contour: watch
  the plot grow until it encircles −1).
- **Tools**: *Draw* (freehand; the curve stays open, unless you end it where
  you started, which closes it), *Move* (drag the contour across a pole or a
  zero, drag a pole or a zero itself, and L(s) follows; complex pairs stay
  conjugate; or drag the empty plane to pan). Mouse wheel: zoom.
- **Nyquist contour**: up the jω axis, indenting to the right of poles on it,
  and back along a large clockwise semicircle.
- **Encirclements of −1**: for a closed contour the demo counts the poles P of
  L inside and the encirclements N of −1 by the image, and gives Z = N + P, the
  zeros of 1 + kL inside, checked against the roots of 1 + kL.
- **Moving point** (Play): a point runs along the contour; the phasors from the
  poles (orange) and zeros (blue) to the point are drawn, with the net turn of
  each one. At the end of the lap only the poles and zeros inside have turned
  by 360°.
- **Phase plot** (bottom): the unwrapped ∠(1 + L) along the contour;
  its net change divided by 360° is the number of encirclements.
- **Compressed scale**: |L| > 1 is drawn at radius 1 + ln|L|, so the image stays
  on the screen when the contour passes near a pole (as for the integrator).

If the contour passes exactly through a pole or a zero, the image goes through
infinity (or the origin): the demo says so and does not count.

## What to try in class

1. Draw an open curve and watch its image grow as you draw.
2. Draw a closed curve around one pole (end where you started) and press Play:
   only the phasor of the enclosed pole turns by 360°.
3. With the Nyquist contour, raise k above 1.2 (K > 60): the plot of
   50/((s+1)(s+2)(s+3)) encircles −1 twice, two closed-loop poles in the RHP.
4. Type the rocket with PI, `(3+9/s)*(s^2-0.5*s+0.5)/(s^3-s^2-2*s+8)`, press
   Nyquist contour and switch to the compressed scale: P = 2, two
   counterclockwise encirclements of −1, Z = 0, stable.

## Requirements

Base MATLAB R2021a or newer (uifigure). No toolboxes.
