%% Damped pendulum - Routh-Hurwitz Control Design
% Damped pendulum from Chapter 1, linearized around the hanging position 
% (theta = 0). The input u is a torque scaled by the inertia and the output is 
% the angle theta.

clear all
close all

k = 1;              % viscous damping [1/s]
g = 9.8;            % gravity [m/s^2]
L = 1;              % length [m]
s = tf('s');

G = 1/(s^2 + k*s + g/L);
%% P controller
% With C(s) = K: P(s) = s^2 + s + 9.8 + K, stable for any K > -9.8, but with a 
% steady state error 1/(1 + K/9.8). We need an integrator.
%% PID controller
% $$C(s) = K\frac{(s+2)(s+3)}{s}$$
% 
% The characteristic equation is s(s^2 + s + 9.8) + K(s^2 + 5s + 6) = 0, i.e.,
% 
% $$P(s) = s^3 + (1 + K)s^2 + (9.8 + 5K)s + 6K$$
% 
% Routh table:
% 
%   s^3 | 1                                        9.8 + 5K
%   s^2 | 1 + K                                    6K
%   s^1 | c11 = ((1 + K)(9.8 + 5K) - 6K)/(1 + K) = (5K^2 + 8.8K + 9.8)/(1 + K)
%   s^0 | c21 = 6K
% 
% For K > 0 all the entries of the first column are positive: the closed loop 
% is stable for any K > 0.
%% 
% We choose K = 10 and add a fast pole at -100 so that C is proper:

K = 10;
C = K*(s+2)*(s+3)/(s*(s/100+1));
pole(minreal(C*G/(1+C*G)))
step(minreal(C*G/(1+C*G)));
%% 
% To try this controller in PEN_Realtime_Demo, set
% 
%   C = 10*(s+2)*(s+3)/(s*(s/100+1));

[numC, denC] = tfdata(C, 'v')
