%% Ball on plate - Routh-Hurwitz Control Design
% Ball on plate from Chapter 1. A servo motor tilts the plate by the angle 
% theta and the ball rolls. Each axis (x and y) is the same, so we design one 
% controller and use it for both. The input is the servo angle command 
% theta_ref and the output is the ball position x.

clear all
close all

c = 1.09;           % ball acceleration per servo angle [m/s^2/rad] (K_bb in the lab)
Km = 1.53;          % servo gain [rad/(V s)]
tau = 0.0248;       % servo time constant [s]
Kp1 = 76.5;         % inner servo loop gain (P control of the servo angle)
s = tf('s');

Gball = c/s^2;
Gservo = Kp1*Km/(tau*s^2 + s + Kp1*Km);
G = Gball*Gservo;
%% Simplified model
% The servo is much faster than the ball, so first we neglect it, G(s) = c/s^2.
% With C(s) = K: P(s) = s^2 + cK, the coefficient of s is zero, never 
% asymptotically stable. With the lead compensator
% 
% $$C(s) = K\frac{s+1}{s/20+1}$$
% 
% the characteristic equation is s^2(s/20 + 1) + cK(s + 1) = 0. Multiplying 
% by 20:
% 
% $$P(s) = s^3 + 20s^2 + 20cKs + 20cK$$
% 
% Routh table:
% 
%   s^3 | 1                                  20cK
%   s^2 | 20                                 20cK
%   s^1 | c11 = (20*20cK - 20cK)/20 = 19cK
%   s^0 | c21 = 20cK
% 
% Stable for any K > 0.
%% Full model
% With the servo, P(s) is of order 5 and an upper limit on K appears: the 
% servo adds phase lag. Let's check a few gains on the full model:

for K = [3 30 100]
    C = K*(s+1)/(s/20+1);
    disp(['K = ' num2str(K) ':']);
    disp(pole(minreal(C*G/(1+C*G))).');
end
%% 
% K = 100 is unstable. Neglecting fast dynamics is useful, but the result must 
% be checked on the full model. We choose K = 3:

K = 3;
C = K*(s+1)/(s/20+1);
step(minreal(C*G/(1+C*G)));
%% 
% To try this controller in BOP_Realtime_Demo, type this in its C(s) box
% 
%   3*(s+1)/(s/20+1)

[numC, denC] = tfdata(C, 'v')
