%% DC motor (servo) - Bode design: lead compensator
% DC motor from Chapter 1 with a negligible armature inductance. The input is
% the armature voltage v and the output is the shaft angle theta. The values
% are those of the ball-on-plate servo. This is Example "DC motor: lead
% compensation" of Chapter 8.
%
% Specifications: static velocity error constant K_v = 100 1/s, phase margin
% of at least 50 deg. We use a lead compensator
%
% $$C(s) = K_c\frac{Ts+1}{\alpha Ts+1}, \qquad 0 < \alpha < 1$$

clear all
close all

K = 1.53;           % steady-state speed gain [rad/(V s)]
tau = 0.0248;       % time constant [s]
s = tf('s');

G = K/(s*(tau*s+1));
%% Step 1: gain for the steady state specification
% $$K_v = \lim_{s\to 0} s C(s) G(s) = 1.53 K_c$$

Kv = 100;
Kc = Kv/K           % = 65.4
%% Step 2: margins of the uncompensated system Kc*G
% The phase -90 - atan(tau w) never reaches -180 deg, so the gain margin is
% infinite. The phase margin is about 35 deg at about 57.5 rad/s: too small.

margin(Kc*G);
[~, PM0, ~, wg0] = margin(Kc*G)
%% Step 3: lead compensator
% Phase the lead must add, with 10 deg extra for the shift of the gain
% crossover frequency to the right:

phicm = 50 - PM0 + 10                          % about 24.9 deg
alpha = (1 - sind(phicm))/(1 + sind(phicm))    % about 0.407
alpha = 0.4;                                   % round it
%% 
% The maximum phase lead is at w_m = 1/(sqrt(alpha) T), where the lead adds 
% 10 log10(1/alpha) dB. We make w_m the new gain crossover frequency, so we look 
% for the frequency where |Kc G(j w_m)| = sqrt(alpha):

wm = fzero(@(w) abs(evalfr(Kc*G, 1j*w)) - sqrt(alpha), [wg0 10*wg0])   % about 74.9 rad/s
T = 1/(wm*sqrt(alpha))                                                 % about 0.0211
%% Step 4: validate
% Rounded values: C(s) = 65.4 (0.0211 s + 1)/(0.00844 s + 1)

C = 65.4*(0.0211*s + 1)/(0.4*0.0211*s + 1);
margin(C*G);                                   % PM about 53.7 deg at 75 rad/s
%% 
% Compare the Bode plots of Kc*G and C*G

bode(Kc*G, C*G); grid on
legend('K_c G(s)', 'C(s) G(s)');
%% 
% and the closed loop step responses: the overshoot drops from about 35% to 
% about 15%. G has a pole at the origin, so the step error is zero.

step(feedback(Kc*G, 1), feedback(C*G, 1), 0.15);
legend('uncompensated', 'compensated');
%% 
% In the simulation the armature voltage saturates at +/-10 V during the large 
% steps, so the response is slower than the linear one (but still without overshoot). 
% To try this controller in DCM_Realtime_Demo (or in the browser version), type 
% this in its C(s) box
%
%   65.4*(0.0211*s+1)/(0.00844*s+1)

[numC, denC] = tfdata(C, 'v')
