%% DC motor (servo) - Routh-Hurwitz Control Design
% DC motor from Chapter 1 with a negligible armature inductance. The input is 
% the armature voltage v and the output is the shaft angle theta. The values 
% are those of the ball-on-plate servo.

clear all
close all

Km = 1.53;          % steady-state speed gain [rad/(V s)]
tau = 0.0248;       % time constant [s]
s = tf('s');

G = Km/(s*(tau*s+1));
%% P controller
% With C(s) = K the characteristic equation is s(tau s + 1) + Km K = 0, i.e.,
% 
% $$P(s) = \tau s^2 + s + K_m K$$
% 
% Routh table:
% 
%   s^2 | tau      Km*K
%   s^1 | 1        0
%   s^0 | Km*K
% 
% The closed loop is stable for any K > 0 (for a second order polynomial, 
% Routh-Hurwitz simply says that all coefficients must be positive).
%% 
% Since every K > 0 is stable, we pick K using another requirement. For 
% example, the closed loop poles are
% 
% $$s = \frac{-1 \pm \sqrt{1 - 4\tau K_m K}}{2\tau}$$
% 
% and they become complex for K > 1/(4 tau Km) = 6.6. With K = 10 they are 
% slightly complex (small overshoot) and fast:

K = 10;
C = K;
pole(minreal(C*G/(1+C*G)))
step(minreal(C*G/(1+C*G)));
%% 
% G has a pole at the origin, so the steady state error to step inputs is 
% zero. To try this controller in DCM_Realtime_Demo, type this in its C(s) box
% 
%   10

[numC, denC] = tfdata(tf(C), 'v')
