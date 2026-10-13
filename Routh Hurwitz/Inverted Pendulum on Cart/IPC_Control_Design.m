%% Inverted pendulum on a cart - Routh-Hurwitz Control Design
% Model from Exercise 4.4: a pendulum (mass m, inertia I, distance l from the
% pivot to its center of mass) is hinged on a cart of mass M. The input u is
% the horizontal force on the cart, the output theta is the pendulum angle
% from the upward vertical, and mu is the cart friction coefficient.

clear all
close all

M = 0.5;     % cart mass [kg]
m = 0.5;     % pendulum mass [kg]
l = 0.3;     % pivot to pendulum center of mass [m]
I = 0.006;   % pendulum inertia [kg m^2]
mu = 0.1;    % cart friction [N s/m]
g = 9.81;    % gravity [m/s^2]
s = tf('s');

q = (M+m)*(I+m*l^2) - (m*l)^2;
alpha = m*l/q;
a2 = mu*(I+m*l^2)/q;
a1 = (M+m)*m*g*l/q;
a0 = mu*m*g*l/q;
%% 
% The transfer function is
% 
% $$G(s) = \frac{-\alpha s}{s^3 + a_2 s^2 - a_1 s - a_0}$$
% 
% with

[alpha a2 a1 a0]

G = -alpha*s/(s^3 + a2*s^2 - a1*s - a0);
%% PID controller
% Pushing the cart to the right makes the pendulum fall to the left, so the 
% controller has a negative gain. G has a zero at the origin, so we need an 
% integrator (see the root locus design):
% 
% $$C(s) = -K\frac{s^2 + 6s + 8}{s}$$
% 
% The s in the numerator of G cancels the s in the denominator of C, and the 
% characteristic equation is (s^3 + a2 s^2 - a1 s - a0) + alpha K (s^2 + 6s + 8) = 0:
% 
% $$P(s) = s^3 + (a_2 + \alpha K)s^2 + (6\alpha K - a_1)s + (8\alpha K - a_0)$$
% 
% Routh table:
% 
%   s^3 | 1                                   6 alpha K - a1
%   s^2 | a2 + alpha K                        8 alpha K - a0
%   s^1 | c11 = ((a2 + alpha K)(6 alpha K - a1) - (8 alpha K - a0))/(a2 + alpha K)
%   s^0 | c21 = 8 alpha K - a0
% 
% For K > 0 the first entry of the s^2 row is positive. We need:
% 
% - c21 > 0, i.e., K > a0/(8 alpha)
% - c11 > 0, i.e., the numerator 
% 6 alpha^2 K^2 + (6 a2 alpha - a1 alpha - 8 alpha) K + (a0 - a1 a2) > 0

K_c21 = a0/(8*alpha)
K_c11 = max(roots([6*alpha^2, 6*a2*alpha - a1*alpha - 8*alpha, a0 - a1*a2]))
%% 
% So the closed loop is stable for K > 1.87. (The pole at -100 that we add 
% in the demo to make C proper changes this limit slightly.) We choose K = 10:

K = 10;
C = -K*(s^2 + 6*s + 8)/s/(s/100+1);
pole(minreal(C*G/(1+C*G)))
%% 
% Response of theta to a 1 N push on the cart:

step(minreal(G/(1+C*G)), 5);
%% 
% To try this controller in IPC_Realtime_Demo, set
% 
%   C = -10*(6 + s + 8/s)/(s/100+1);

[numC, denC] = tfdata(C, 'v')
