%% Damped pendulum - Bode design: lead-lag compensator
% Damped pendulum from Chapter 1, linearized around the hanging position 
% (theta = 0). The input u is a torque scaled by the inertia and the output is 
% the angle theta. This is Example "Hanging pendulum: lead-lag compensation" of 
% Chapter 8.
%
% Specifications: K_p = 20 (steady state error to a step 1/21, about 4.8%), 
% phase margin of at least 45 deg, and gain crossover frequency between 5 and 
% 10 rad/s (faster than the pendulum, but without amplifying noise too much).

clear all
close all

k = 1;              % viscous damping [1/s]
g = 9.8;            % gravity [m/s^2]
L = 1;              % length [m]
s = tf('s');

G = 1/(s^2 + k*s + g/L);
phaseDeg = @(H, w) angle(evalfr(H, 1j*w))*180/pi;
%% Step 1: gain for the steady state specification
% $$K_p = \lim_{s\to 0} C(s) G(s) = K_c/9.8$$

Kc = 20*g/L         % = 196
%% Step 2: margins of the uncompensated system Kc*G
% The pendulum is very lightly damped (zeta = 0.16): the phase drops sharply to 
% almost -180 deg after the resonance. Phase margin about 4.2 deg at 14.3 rad/s.

margin(Kc*G);
[~, PM0, ~, wg0] = margin(Kc*G)
%% Attempt 1: lead only
% The lead procedure meets the phase margin, but the gain crossover moves to 
% about 23.7 rad/s (> 10) and the high frequency gain of the controller is 
% Kc/alpha, about 1550.

phicm = 45 - PM0 + 10;
a = (1 - sind(phicm))/(1 + sind(phicm))                          % about 0.127
wm = fzero(@(w) abs(evalfr(Kc*G, 1j*w)) - sqrt(a), [wg0 100]);
Clead = Kc*(s/(wm*sqrt(a)) + 1)/(a*s/(wm*sqrt(a)) + 1);
margin(Clead*G);
%% Attempt 2: lag only
% The lag procedure (phase -125 deg) gives a crossover of 3.5 rad/s (< 5): the 
% phase margin is met, but the loop is too slow.

wc = fzero(@(w) phaseDeg(G, w) + 125, [1 10]);                   % about 3.5 rad/s
beta = abs(evalfr(Kc*G, 1j*wc));                                 % about 45.9
Clag = Kc*(10/wc*s + 1)/(beta*10/wc*s + 1);
margin(Clag*G);
%% Lead-lag: lag part
% Choose the new crossover wc = 6 rad/s, inside the required range. There the 
% phase of Kc*G is about -167 deg, so the lead will have to add about 40 deg.

wc = 6;
phaseDeg(Kc*G, wc)
beta = abs(evalfr(Kc*G, 1j*wc))                % about 7.29
T2 = 10/wc;                                    % lag zero at wc/10 = 0.6 rad/s
Clag = (T2*s + 1)/(beta*T2*s + 1);
[~, PM1, ~, wg1] = margin(Kc*Clag*G)           % PM about 7.9 deg at 6 rad/s
%% Lead-lag: lead part
% Phase to add (5 deg extra: above 6 rad/s the phase of Kc*G is almost flat)

phicm = 45 - PM1 + 5                           % about 42.1 deg
alpha = (1 - sind(phicm))/(1 + sind(phicm))    % about 0.198
alpha = 0.2;                                   % round it
wm = fzero(@(w) abs(evalfr(Kc*Clag*G, 1j*w)) - sqrt(alpha), [wg1 100])   % about 8.34 rad/s
T1 = 1/(wm*sqrt(alpha))                                                  % about 0.268
%% Validate
% Rounded values: C(s) = 196 (0.268 s + 1)/(0.0537 s + 1) (1.667 s + 1)/(12.15 s + 1)

C = 196*(0.268*s + 1)/(0.0537*s + 1)*(1.667*s + 1)/(12.15*s + 1);
margin(C*G);                                   % PM about 46.2 deg at 8.34 rad/s
%% 
% Compare the Bode plots

bode(Kc*G, Clead*G, Clag*G, C*G); grid on
legend('K_c G(s)', 'lead only', 'lag only', 'lead-lag');
%% 
% and the closed loop step responses: the uncompensated loop rings for 
% seconds, the lead-lag overshoots by about 20% and then approaches the final 
% value 0.952 slowly (closed loop pole at -0.45 from the lag).

step(feedback(Kc*G, 1), feedback(C*G, 1), 10);
legend('uncompensated', 'lead-lag');
%% 
% The high frequency gain of the lead-lag is Kc/(alpha beta), about 134, 
% versus about 1550 for the lead only: in the simulation the input is limited to 
% +/-50. To try this controller in PEN_Realtime_Demo (or in the browser version), 
% type this in its C(s) box
%
%   196*(0.268*s+1)/(0.0537*s+1)*(1.667*s+1)/(12.15*s+1)

[numC, denC] = tfdata(C, 'v')
