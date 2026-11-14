%% Rear-steered bicycle - Routh-Hurwitz Control Design
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
%% P controller
% With C(s) = K the characteristic equation is
%
% $$P(s) = s^2 - 9.81 + 1.5K(6 - s) = s^2 - 1.5Ks + 9K - 9.81$$
%
% For K > 0 the coefficient of s is negative, for K < 0 the constant term is
% negative: no K makes the closed loop stable. (The RHP zero is the reason: it
% gives the s coefficient the wrong sign.)
%% PD controller (ideal, not proper)
% $$C(s) = K(1 + T_d s)$$
%
% $$P(s) = (1 - 1.5KT_d)s^2 + 1.5K(6T_d - 1)s + 9K - 9.81$$
%
% For a second-order polynomial all coefficients must have the same sign:
% K > 1.09, T_d > 1/6 and K T_d < 2/3. The derivative action is what
% stabilizes the bicycle, but a PD is not proper. We add a pole: a lead.
%% Lead controller
% $$C(s) = K\frac{s + 3}{s + 20}$$
%
% The characteristic equation is (s + 20)(s^2 - 9.81) + 1.5K(s + 3)(6 - s) = 0:
%
% $$P(s) = s^3 + (20 - 1.5K)s^2 + (4.5K - 9.81)s + 27K - 196.2$$
%
% Routh table:
%
%   s^3 | 1                                    4.5K - 9.81
%   s^2 | 20 - 1.5K                            27K - 196.2
%   s^1 | c11 = K(77.715 - 6.75K)/(20 - 1.5K)
%   s^0 | 27K - 196.2
%
% First column positive: K < 13.33 (s^2), K < 11.51 (s^1), K > 7.27 (s^0).
% The closed loop is stable for 7.27 < K < 11.51. Let's check it:

C1 = (s + 3)/(s + 20);
pole(feedback(7.2*C1*G, 1))    % K = 7.2: unstable
pole(feedback(7.3*C1*G, 1))    % K = 7.3: stable
pole(feedback(11.5*C1*G, 1))   % K = 11.5: stable
pole(feedback(11.6*C1*G, 1))   % K = 11.6: unstable
%%
% We choose K = 9, in the middle of the range:

K = 9;
C = K*C1;
pole(feedback(C*G, 1))         % -2.15 +- 4.08j, -2.21
impulse(feedback(C*G, 1), 3);
%% How fast must the bicycle go?
% Keep C(s) = 9(s+3)/(s+20) and let the speed V change. With k = aV/(bh) = V/2
% and z = V/a = 2V:
%
% $$P(s) = s^3 + (20 - 4.5V)s^2 + (9V^2 - 13.5V - 9.81)s + 27V^2 - 196.2$$
%
% The constant term needs V > 2.70 m/s, the s^1 row of the Routh table
% (20 - 4.5V)(9V^2 - 13.5V - 9.81) - (27V^2 - 196.2) > 0 needs V < 3.82 m/s.
% This controller only works between 2.70 and 3.82 m/s: try it with the speed
% slider of BIKE_Realtime_Demo. (Below a*sqrt(g/h) = 1.57 m/s the zero is left
% of the unstable pole and no stable controller works at all.)

Vs = 2.5:0.01:4;
stab = arrayfun(@(v) all(real(roots([1, 20 - 4.5*v, 9*v^2 - 13.5*v - 9.81, 27*v^2 - 196.2])) < 0), Vs);
[min(Vs(stab)) max(Vs(stab))]
%%
% To try this controller in BIKE_Realtime_Demo, type this in its C(s) box
%
%   9*(s+3)/(s+20)

[numC, denC] = tfdata(C, 'v')
