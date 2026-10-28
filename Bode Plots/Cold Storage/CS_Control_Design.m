%% Cold storage unit - Bode design: PI controller
% Cold storage unit from Chapter 1:
% 
% $$\frac{dT}{dt} = -h(T - T_a) - P$$
% 
% where P >= 0 is the cooling power. More cooling lowers the temperature, so 
% by convention (and without loss of generality) we take as input u = -P. Then
% 
% $$\frac{dT}{dt} = -h(T - T_a) + u$$
% 
% and, with h = 1, the transfer function from u to T is G(s) = 1/(s+1), with 
% a positive gain. The ambient temperature acts as a constant disturbance. The 
% cooling power applied by the AC is P = -u.
%
% Specifications: zero steady state error to a step in the commanded 
% temperature (and to a constant ambient temperature), phase margin of at least 
% 60 deg, gain crossover frequency of 2 rad/s.

clear all
close all

h = 1;              % heat transfer constant [1/s]
s = tf('s');

G = 1/(s + h);
%% Step 1: integral action for the steady state specification
% G has no pole at the origin, so the controller needs an integrator. Start 
% with the integral controller of Chapter 1, C(s) = 1/s:

C = 1/s;
margin(C*G);
[GM, PM, wp, wg] = margin(C*G)
%% 
% The phase -90 - atan(w) never reaches -180 deg, so the gain margin is 
% infinite. The phase margin is about 52 deg at about 0.79 rad/s: too small, 
% and the crossover is too low (slow response). Raising the gain moves the 
% crossover to the right but lowers the phase margin further.
%% Step 2: PI controller
% Add a zero to the integrator:
% 
% $$C(s) = K\frac{s+a}{s}$$
% 
% Putting the zero on the pole of G (a = h = 1) cancels the phase lag of the pole 
% (from 0 to -90 deg), so that L(s) = C(s)G(s) = K/s: the magnitude is a line 
% of slope -20 dB/decade crossing 0 dB at w = K, and the phase is -90 deg at 
% every frequency. The phase margin is 90 deg for any K > 0, and the gain 
% crossover frequency is K. For a crossover of 2 rad/s we take K = 2:

C = 2*(s + 1)/s;
margin(C*G);                                   % PM = 90 deg at 2 rad/s
%% Step 3: validate
% Compare the Bode plots of the integral and PI loops

bode(G/s, C*G); grid on
legend('G(s)/s', 'C(s) G(s)');
%% 
% and the closed loop step responses. With the PI controller the closed loop is 
% 2/(s+2): first order, no overshoot, time constant 0.5 s, zero steady state 
% error.

step(feedback(G/s, 1), feedback(C*G, 1), 8);
legend('integral, C = 1/s', 'PI, C = 2(s+1)/s');
pole(feedback(C*G, 1))
%% 
% Note that the AC can only cool (P >= 0, i.e., u <= 0): it cannot heat the 
% room if the temperature drops below the target.
% 
% To try this controller in CS_Realtime_Demo (or in the browser version), type 
% this in its C(s) box
%
%   2*(s+1)/s

[numC, denC] = tfdata(C, 'v')
