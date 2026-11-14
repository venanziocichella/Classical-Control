%% Rear-steered bicycle - Root Locus Control Design
% Bicycle with rear-wheel steering (Chapter 1 running example), linearized
% around the upright position. Input: rear steering angle delta. Output: lean
% angle phi. With a = 0.5 m, b = 1 m, h = 1 m, V = 3 m/s:
%
% $$G(s) = \frac{aV}{bh}\,\frac{V/a - s}{s^2 - g/h} = \frac{1.5(6 - s)}{s^2 - 9.81}$$
%
% Unstable pole at +3.13 (the bicycle falls) and a right-half-plane zero at +6.

clear all
close all

a = 0.5; b = 1; h = 1; g = 9.81; V = 3;
s = tf('s');

G = a*V/(b*h)*(V/a - s)/(s^2 - g/h)
%%
% Plot the root locus of G (C = K > 0):

rlocus(G);
%%
% The leading coefficient of G is negative (-1.5s + 9), so the locus of
% 1 + KG = 0 for K > 0 follows the 0-degree rules: on the real axis it is the
% segment between the poles -3.13 and +3.13 and the half line to the right of
% the zero +6. The two branches meet between the poles, leave the real axis
% into the right half plane, come back to it to the right of +6 and end at the
% zero +6 and at +infinity. Indeed P(s) = s^2 - 1.5Ks + 9K - 9.81: the sum of
% the closed-loop poles is 1.5K > 0, so at least one of them is always in the
% right half plane. No gain stabilizes the bicycle: we need a compensator that
% pulls the locus to the left.
%% Lead compensator
% A zero at -3 pulls the branches into the left half plane (it acts like a
% derivative), and a pole far to the left at -20 makes C(s) proper:
%
% $$C(s) = K\frac{s + 3}{s + 20}$$

C1 = (s + 3)/(s + 20);
rlocus(C1*G);
axis([-25 10 -10 10]);
%%
% Now there is a range of gains with all poles in the left half plane. Let's
% find it, and the gain that makes the slowest pole as fast as possible:

Ks = 0.05:0.05:15;
slowest = arrayfun(@(k) max(real(pole(feedback(k*C1*G, 1)))), Ks);
stableK = Ks(slowest < 0);
[min(stableK) max(stableK)]           % about 7.3 and 11.5 (Routh: 7.27 < K < 11.51)
[~, i] = min(slowest); Ks(i)          % about 9
plot(Ks, slowest); grid on; xlabel('K'); ylabel('largest real part of the closed-loop poles');
%%
% We choose K = 9. The closed-loop poles are -2.15 +- 4.08j and -2.21:

K = 9;
C = K*C1;
rlocus(C1*G); hold on
p = pole(feedback(C*G, 1));
plot(real(p), imag(p), 'rs', 'MarkerSize', 10, 'LineWidth', 2); hold off
axis([-25 10 -10 10]);
p
%%
% Change the speed V in BIKE_Realtime_Demo: the zero V/a moves (the pole does
% not), and the locus changes with it. With this C(s) the bicycle stays up only
% between about 2.7 and 3.8 m/s. Below a*sqrt(g/h) = 1.57 m/s the RHP zero is
% left of the unstable pole and no stable controller can keep the bicycle up.
%
% To try this controller in BIKE_Realtime_Demo, type this in its C(s) box
%
%   9*(s+3)/(s+20)

[numC, denC] = tfdata(C, 'v')
